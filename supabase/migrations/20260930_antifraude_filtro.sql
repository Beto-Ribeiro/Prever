-- ============================================================
-- Migration: Filtro Antifraude
-- Branch: feature/filtro-antifraude
-- Data: 2026-09-30
-- ============================================================
--
-- Adiciona as colunas necessárias para o sistema de detecção
-- de fraudes baseado em IA (Gemini) na tabela de Relatos.
--
-- Campos adicionados:
--   rel_gravidade           - Separação correta da gravidade (era gravado em rel_descricao)
--   rel_fraud_status        - Status da análise antifraude
--   rel_fraud_score         - Score de autenticidade (0.0 a 1.0)
--   rel_fraud_reason        - Motivo da classificação pela IA
--   rel_needs_admin_review  - Se precisa de validação humana antes de publicar
--   rel_prioridade          - Prioridade do relato (normal | baixa)
-- ============================================================

-- 1. Adiciona coluna de gravidade separada da descrição
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_gravidade VARCHAR(20) DEFAULT NULL;

-- 2. Status da análise antifraude
--    Valores possíveis: 'aprovado', 'pendente_revisao'
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_status VARCHAR(30) NOT NULL DEFAULT 'aprovado';

-- 3. Score de autenticidade (0.0 = fraude total, 1.0 = totalmente legítimo)
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_score FLOAT DEFAULT NULL;

-- 4. Motivo textual da classificação retornado pelo Gemini
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_fraud_reason TEXT DEFAULT NULL;

-- 5. Flag de revisão administrativa obrigatória
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_needs_admin_review BOOLEAN NOT NULL DEFAULT FALSE;

-- 6. Nível de prioridade do relato
--    Valores possíveis: 'normal', 'baixa'
ALTER TABLE public."Relato"
  ADD COLUMN IF NOT EXISTS rel_prioridade VARCHAR(10) NOT NULL DEFAULT 'normal';

-- ============================================================
-- Índices para otimizar consultas do painel admin
-- ============================================================

-- Índice para filtrar relatos que precisam de revisão
CREATE INDEX IF NOT EXISTS idx_relato_needs_admin_review
  ON public."Relato" (rel_needs_admin_review)
  WHERE rel_needs_admin_review = TRUE;

-- Índice para filtrar por status antifraude
CREATE INDEX IF NOT EXISTS idx_relato_fraud_status
  ON public."Relato" (rel_fraud_status);

-- Índice para filtrar por prioridade
CREATE INDEX IF NOT EXISTS idx_relato_prioridade
  ON public."Relato" (rel_prioridade);

-- ============================================================
-- View para o painel administrativo
-- Exibe apenas os relatos pendentes de revisão, ordenados
-- por gravidade (Severa primeiro) e data (mais recente primeiro)
-- ============================================================

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
  -- Ordena gravidade numericamente para facilitar ORDER BY
  CASE r.rel_gravidade
    WHEN 'Severa'   THEN 1
    WHEN 'Moderada' THEN 2
    WHEN 'Leve'     THEN 3
    ELSE 4
  END AS gravidade_ordem
FROM public."Relato" r
WHERE r.rel_needs_admin_review = TRUE
  AND r.rel_fraud_status = 'pendente_revisao'
ORDER BY gravidade_ordem ASC, r.rel_data_hora DESC;

-- ============================================================
-- Comentários nas colunas para documentação
-- ============================================================

COMMENT ON COLUMN public."Relato".rel_fraud_status IS
  'Status da análise antifraude: aprovado | pendente_revisao';

COMMENT ON COLUMN public."Relato".rel_fraud_score IS
  'Score de autenticidade de 0.0 (fraude) a 1.0 (legítimo) retornado pelo Gemini';

COMMENT ON COLUMN public."Relato".rel_fraud_reason IS
  'Explicação em linguagem natural sobre a classificação feita pela IA';

COMMENT ON COLUMN public."Relato".rel_needs_admin_review IS
  'TRUE = relato suspeito que precisa de validação humana antes de ser publicado';

COMMENT ON COLUMN public."Relato".rel_prioridade IS
  'Prioridade do relato: normal (legítimo) | baixa (suspeito de fraude)';
