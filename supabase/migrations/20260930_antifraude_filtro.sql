-- ============================================================
-- Migration: Filtro Antifraude com IA (Gemini)
-- Branch: feature/filtro-antifraude
-- Data: 2026-09-30
-- ============================================================
-- Contexto do schema existente:
--
--   Relato (rel_id, rel_tipo_desastre, rel_descricao, rel_data_hora,
--           rel_cid_id → Cidadao, rel_localizacao)
--
--   Ocorrencia_Status (ocs_rel_id → Relato, ocs_status, ocs_updated_by,
--                      ocs_updated_at)
--   ocs_status: 'active' | 'monitoring' | 'resolved'
--
-- IMPORTANTE: Relatos suspeitos NÃO devem gerar entradas em
-- Ocorrencia_Status automaticamente — o trigger abaixo garante isso.
-- ============================================================


-- ============================================================
-- PARTE 1 — Novas colunas na tabela Relato
-- ============================================================

-- 1a. Separação correta da gravidade (o código original gravava
--     o nível de risco em rel_descricao — bug corrigido no app)
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_gravidade VARCHAR(20) DEFAULT NULL;

-- 1b. Status da análise antifraude
--     'aprovado'         → relato legítimo, publicado normalmente
--     'pendente_revisao' → suspeito, aguarda validação humana
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_status VARCHAR(30)
    NOT NULL DEFAULT 'aprovado';

-- 1c. Score de autenticidade retornado pelo Gemini (0.0 → fraude, 1.0 → legítimo)
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_score FLOAT DEFAULT NULL;

-- 1d. Motivo textual da classificação gerado pela IA
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_reason TEXT DEFAULT NULL;

-- 1e. Flag: TRUE = admin precisa validar antes do relato ser publicado
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_needs_admin_review BOOLEAN
    NOT NULL DEFAULT FALSE;

-- 1f. Prioridade de exibição: 'normal' (legítimo) | 'baixa' (suspeito)
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_prioridade VARCHAR(10)
    NOT NULL DEFAULT 'normal';


-- ============================================================
-- PARTE 2 — Índices para otimizar consultas do painel admin
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_relato_needs_admin_review
  ON public."Relato" (rel_needs_admin_review)
  WHERE rel_needs_admin_review = TRUE;

CREATE INDEX IF NOT EXISTS idx_relato_fraud_status
  ON public."Relato" (rel_fraud_status);

CREATE INDEX IF NOT EXISTS idx_relato_prioridade
  ON public."Relato" (rel_prioridade);


-- ============================================================
-- PARTE 3 — Integração com Ocorrencia_Status
--
-- O painel web usa Ocorrencia_Status para exibir ocorrências
-- ativas. Relatos suspeitos NÃO podem entrar nesse fluxo
-- automaticamente — precisam ser aprovados por um admin primeiro.
-- ============================================================

-- Função chamada pelo trigger: bloqueia INSERT em Ocorrencia_Status
-- para relatos com rel_needs_admin_review = TRUE.
CREATE OR REPLACE FUNCTION public.fn_bloquear_ocorrencia_suspeita()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_needs_review BOOLEAN;
BEGIN
  SELECT rel_needs_admin_review
    INTO v_needs_review
    FROM public."Relato"
   WHERE rel_id = NEW.ocs_rel_id;

  IF v_needs_review IS TRUE THEN
    RAISE EXCEPTION
      'Relato % está pendente de revisão antifraude. '
      'Aprovação de admin necessária antes de criar a ocorrência.',
      NEW.ocs_rel_id;
  END IF;

  RETURN NEW;
END;
$$;

-- Trigger disparado ANTES de qualquer INSERT em Ocorrencia_Status
DROP TRIGGER IF EXISTS trg_bloquear_ocorrencia_suspeita
  ON public."Ocorrencia_Status";

CREATE TRIGGER trg_bloquear_ocorrencia_suspeita
  BEFORE INSERT ON public."Ocorrencia_Status"
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_ocorrencia_suspeita();


-- ============================================================
-- PARTE 4 — Função utilitária para o painel admin aprovar/rejeitar
--
-- Uso:
--   SELECT aprovar_relato(rel_id, auth.uid());   → aprova e ativa
--   SELECT rejeitar_relato(rel_id, auth.uid());  → descarta o relato
-- ============================================================

-- Aprova um relato suspeito: atualiza o Relato e cria a Ocorrencia_Status
CREATE OR REPLACE FUNCTION public.aprovar_relato(
  p_rel_id UUID,
  p_admin_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Atualiza o status do relato para aprovado
  UPDATE public."Relato"
     SET rel_fraud_status      = 'aprovado',
         rel_needs_admin_review = FALSE,
         rel_prioridade         = 'normal'
   WHERE rel_id = p_rel_id;

  -- Agora que needs_admin_review = FALSE, o trigger deixa passar
  INSERT INTO public."Ocorrencia_Status" (ocs_rel_id, ocs_status, ocs_updated_by)
  VALUES (p_rel_id, 'active', p_admin_id)
  ON CONFLICT (ocs_rel_id) DO UPDATE
    SET ocs_status     = 'active',
        ocs_updated_by = p_admin_id,
        ocs_updated_at = now();

  -- Registra no Audit_Log para rastreabilidade
  INSERT INTO public."Audit_Log" (actor_user_id, action, entity_type, entity_id, detail)
  VALUES (
    p_admin_id,
    'APROVAR_RELATO_SUSPEITO',
    'Relato',
    p_rel_id,
    'Relato suspeito aprovado manualmente pelo administrador após revisão antifraude.'
  );
END;
$$;

-- Rejeita (descarta) um relato suspeito — mantém no banco mas marcado
CREATE OR REPLACE FUNCTION public.rejeitar_relato(
  p_rel_id UUID,
  p_admin_id UUID,
  p_motivo TEXT DEFAULT 'Rejeitado após revisão manual de fraude.'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public."Relato"
     SET rel_fraud_status      = 'rejeitado',
         rel_needs_admin_review = FALSE,
         rel_fraud_reason       = p_motivo
   WHERE rel_id = p_rel_id;

  INSERT INTO public."Audit_Log" (actor_user_id, action, entity_type, entity_id, detail)
  VALUES (
    p_admin_id,
    'REJEITAR_RELATO_SUSPEITO',
    'Relato',
    p_rel_id,
    p_motivo
  );
END;
$$;

-- Atualiza CHECK do rel_fraud_status para incluir 'rejeitado'
ALTER TABLE public."Relato"
  DROP CONSTRAINT IF EXISTS relato_fraud_status_check;

ALTER TABLE public."Relato"
  ADD CONSTRAINT relato_fraud_status_check
    CHECK (rel_fraud_status IN ('aprovado', 'pendente_revisao', 'rejeitado'));


-- ============================================================
-- PARTE 5 — Views para o painel admin
-- ============================================================

-- View principal: relatos pendentes de revisão com dados do cidadão
CREATE OR REPLACE VIEW public.v_relatos_pendentes_revisao AS
SELECT
  r.rel_id,
  r.rel_tipo_desastre,
  r.rel_gravidade,
  r.rel_descricao,
  r.rel_data_hora,
  r.rel_fraud_status,
  r.rel_fraud_score,
  r.rel_fraud_reason,
  r.rel_prioridade,
  r.rel_cid_id,
  -- Dados do cidadão que enviou (via Perfis)
  p.prf_nome          AS cid_nome,
  p.prf_email_contato AS cid_email,
  -- Ordena por gravidade (Severa = mais urgente)
  CASE r.rel_gravidade
    WHEN 'Severa'   THEN 1
    WHEN 'Moderada' THEN 2
    WHEN 'Leve'     THEN 3
    ELSE 4
  END AS gravidade_ordem
FROM public."Relato" r
JOIN public."Perfis" p ON p.prf_id = r.rel_cid_id
WHERE r.rel_needs_admin_review = TRUE
  AND r.rel_fraud_status = 'pendente_revisao'
ORDER BY gravidade_ordem ASC, r.rel_data_hora DESC;


-- ============================================================
-- PARTE 6 — Documentação das colunas
-- ============================================================

COMMENT ON COLUMN public."Relato".rel_gravidade IS
  'Nível de risco do evento: Leve | Moderada | Severa. '
  'Separado de rel_descricao (corrige bug original).';

COMMENT ON COLUMN public."Relato".rel_fraud_status IS
  'Status antifraude: aprovado | pendente_revisao | rejeitado';

COMMENT ON COLUMN public."Relato".rel_fraud_score IS
  'Score de autenticidade (0.0=fraude, 1.0=legítimo) retornado pelo Gemini';

COMMENT ON COLUMN public."Relato".rel_fraud_reason IS
  'Explicação em português gerada pela IA sobre a classificação do relato';

COMMENT ON COLUMN public."Relato".rel_needs_admin_review IS
  'TRUE = relato suspeito aguardando validação humana. '
  'Enquanto TRUE, o trigger impede criação de Ocorrencia_Status.';

COMMENT ON COLUMN public."Relato".rel_prioridade IS
  'Prioridade de atenção: normal (legítimo) | baixa (suspeito de fraude)';
