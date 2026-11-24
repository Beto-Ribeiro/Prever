-- ============================================================================
-- 21_antifraude_filtro.sql
-- Consolida e endurece (OWASP / RLS / SECURITY DEFINER) a migração do filtro
-- antifraude com IA (Gemini) em /supabase/sql, garantindo verificação estrita
-- de auth.uid() e search_path = public nas RPCs administrativas.
-- ============================================================================

-- 1) Colunas de antifraude e gravidade na tabela Relato
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_gravidade VARCHAR(20) DEFAULT NULL;

ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_status VARCHAR(30)
    NOT NULL DEFAULT 'aprovado';

ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_score FLOAT DEFAULT NULL;

ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_reason TEXT DEFAULT NULL;

ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_needs_admin_review BOOLEAN
    NOT NULL DEFAULT FALSE;

ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_prioridade VARCHAR(10)
    NOT NULL DEFAULT 'normal';

ALTER TABLE public."Relato"
  DROP CONSTRAINT IF EXISTS relato_fraud_status_check;

ALTER TABLE public."Relato"
  ADD CONSTRAINT relato_fraud_status_check
    CHECK (rel_fraud_status IN ('aprovado', 'pendente_revisao', 'rejeitado'));

-- 2) Índices para consultas do painel de validação
CREATE INDEX IF NOT EXISTS idx_relato_needs_admin_review
  ON public."Relato" (rel_needs_admin_review)
  WHERE rel_needs_admin_review = TRUE;

CREATE INDEX IF NOT EXISTS idx_relato_fraud_status
  ON public."Relato" (rel_fraud_status);

CREATE INDEX IF NOT EXISTS idx_relato_prioridade
  ON public."Relato" (rel_prioridade);

-- 3) Helper de autorização para moderação antifraude (somente Admin / Defesa Civil / Bombeiros / Permissão validacao)
CREATE OR REPLACE FUNCTION public.can_moderate_antifraud()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public."Administrador" adm
      WHERE adm.adm_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public."Perfis" p
      WHERE p.prf_id = auth.uid()
        AND (
          lower(coalesce(p.prf_tipo, '')) IN (
            'admin', 'adm', 'administrador', 'administradora',
            'defesa_civil', 'bombeiros'
          )
          OR coalesce((p.prf_permissoes->>'validacao')::boolean, false) = true
        )
    )
  );
$$;

-- 4) Trigger bloqueando entrada automática de relatos suspeitos em Ocorrencia_Status
CREATE OR REPLACE FUNCTION public.fn_bloquear_ocorrencia_suspeita()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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
      'Relato % está pendente de revisão antifraude. Aprovação necessária antes de ativar ocorrência.',
      NEW.ocs_rel_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_bloquear_ocorrencia_suspeita
  ON public."Ocorrencia_Status";

CREATE TRIGGER trg_bloquear_ocorrencia_suspeita
  BEFORE INSERT ON public."Ocorrencia_Status"
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bloquear_ocorrencia_suspeita();

-- 5) RPCs seguras de aprovação e rejeição (usam auth.uid() real em vez de confiar em p_admin_id do cliente)
CREATE OR REPLACE FUNCTION public.aprovar_relato(
  p_rel_id UUID,
  p_admin_id UUID DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
BEGIN
  IF NOT public.can_moderate_antifraud() THEN
    RAISE EXCEPTION 'Acesso negado: permissão insuficiente para aprovar relatos suspeitos.';
  END IF;

  UPDATE public."Relato"
     SET rel_fraud_status       = 'aprovado',
         rel_needs_admin_review = FALSE,
         rel_prioridade         = 'normal'
   WHERE rel_id = p_rel_id;

  INSERT INTO public."Ocorrencia_Status" (ocs_rel_id, ocs_status, ocs_updated_by)
  VALUES (p_rel_id, 'active', v_actor_id)
  ON CONFLICT (ocs_rel_id) DO UPDATE
    SET ocs_status     = 'active',
        ocs_updated_by = v_actor_id,
        ocs_updated_at = now();

  INSERT INTO public."Audit_Log" (actor_user_id, action, entity_type, entity_id, detail)
  VALUES (
    v_actor_id,
    'APROVAR_RELATO_SUSPEITO',
    'Relato',
    p_rel_id,
    'Relato suspeito aprovado manualmente após revisão antifraude.'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.rejeitar_relato(
  p_rel_id UUID,
  p_admin_id UUID DEFAULT NULL,
  p_motivo TEXT DEFAULT 'Rejeitado após revisão manual de fraude.'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id UUID := auth.uid();
BEGIN
  IF NOT public.can_moderate_antifraud() THEN
    RAISE EXCEPTION 'Acesso negado: permissão insuficiente para rejeitar relatos suspeitos.';
  END IF;

  UPDATE public."Relato"
     SET rel_fraud_status       = 'rejeitado',
         rel_needs_admin_review = FALSE,
         rel_prioridade         = 'baixa',
         rel_fraud_reason       = coalesce(nullif(trim(p_motivo), ''), 'Rejeitado após revisão manual de fraude.')
   WHERE rel_id = p_rel_id;

  INSERT INTO public."Audit_Log" (actor_user_id, action, entity_type, entity_id, detail)
  VALUES (
    v_actor_id,
    'REJEITAR_RELATO_SUSPEITO',
    'Relato',
    p_rel_id,
    coalesce(nullif(trim(p_motivo), ''), 'Rejeitado após revisão manual de fraude.')
  );
END;
$$;

REVOKE ALL ON FUNCTION public.aprovar_relato(UUID, UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.aprovar_relato(UUID, UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.rejeitar_relato(UUID, UUID, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rejeitar_relato(UUID, UUID, TEXT) TO authenticated;

-- 6) View com security_invoker = true para respeitar RLS das tabelas subjacentes
CREATE OR REPLACE VIEW public.v_relatos_pendentes_revisao
WITH (security_invoker = true) AS
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
  p.prf_nome          AS cid_nome,
  p.prf_email_contato AS cid_email,
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
