// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.
// Source: shared/schema/domain.schema.json
// Generator: scripts/generate-shared-contracts.mjs

export const SEVERITY_LEVELS = Object.freeze({
  CRITICO: 'Crítico',
  GRAVE: 'Grave',
  MODERADO: 'Moderado',
})

export const SHELTER_STATUSES = Object.freeze({
  DISPONIVEL: 'disponivel',
  QUASE_LOTADO: 'quase_lotado',
  LOTADO: 'lotado',
  INATIVO: 'inativo',
})

export const USER_ROLES = Object.freeze({
  ADMIN: 'admin',
  ADMINISTRADOR: 'administrador',
  DEFESA_CIVIL: 'defesa_civil',
  BOMBEIROS: 'bombeiros',
  FUNCIONARIO: 'funcionario',
  AGENTE: 'agente',
  INSTITUICAO: 'instituicao',
  SHELTER_MANAGER: 'shelter_manager',
  CIDADAO: 'cidadao',
  PENDENTE: 'pendente',
})

export const OCCURRENCE_VALIDATION_STATUSES = Object.freeze({
  LEGITIMO: 'legitimo',
  PENDENTE_REVISAO: 'pendente_revisao',
  REJEITADO: 'rejeitado',
})

export const SEVERITY_VISUAL_TOKENS = Object.freeze({
  "Crítico": Object.freeze({
    color: '#c60202',
    colorBlindSafe: '#005cab',
    radiusMeters: 3000,
    opacity: 0.24,
    shape: 'critical',
    label: 'Crítico',
  }),
  "Grave": Object.freeze({
    color: '#ff6a00',
    colorBlindSafe: '#d95f02',
    radiusMeters: 2300,
    opacity: 0.2,
    shape: 'severe',
    label: 'Grave',
  }),
  "Moderado": Object.freeze({
    color: '#cab900',
    colorBlindSafe: '#7570b3',
    radiusMeters: 1700,
    opacity: 0.18,
    shape: 'regular',
    label: 'Moderado',
  }),
})

export const DEFAULT_WEB_PERMISSIONS = Object.freeze({
  dashboard: true,
  reportar: false,
  ocorrencias: true,
  relatorios: false,
  validacao: false,
  auditoria: false,
})

export const ANTIFRAUD_CONFIG = Object.freeze({
  MIN_LEGITIMATE_SCORE: 0.8,
  MODEL_NAME: 'gemini-2.5-flash-lite',
  FALLBACK_STATUS: 'pendente_revisao',
})

/** Normaliza um objeto bruto em PerfilUsuarioDto. */
export function createPerfilUsuarioDto(raw = {}) {
  return {
    prf_id: raw.prf_id != null ? String(raw.prf_id) : '',
    prf_nome: raw.prf_nome != null ? String(raw.prf_nome) : '',
    prf_cpf: raw.prf_cpf != null ? String(raw.prf_cpf) : null,
    prf_rg: raw.prf_rg != null ? String(raw.prf_rg) : null,
    prf_telefone: raw.prf_telefone != null ? String(raw.prf_telefone) : null,
    prf_email_contato: raw.prf_email_contato != null ? String(raw.prf_email_contato) : null,
    prf_tipo: raw.prf_tipo != null ? String(raw.prf_tipo) : 'cidadao',
    prf_instituicao: raw.prf_instituicao != null ? String(raw.prf_instituicao) : null,
    prf_acesso_web: raw.prf_acesso_web != null ? Boolean(raw.prf_acesso_web) : false,
    prf_admin_web: raw.prf_admin_web != null ? Boolean(raw.prf_admin_web) : false,
    prf_avatar_url: raw.prf_avatar_url != null ? String(raw.prf_avatar_url) : null,
    prf_abrigo_id: raw.prf_abrigo_id != null ? String(raw.prf_abrigo_id) : null,
    prf_ultimo_login_web: raw.prf_ultimo_login_web != null ? String(raw.prf_ultimo_login_web) : null,
    created_at: raw.created_at != null ? String(raw.created_at) : null,
  }
}

/** Normaliza um objeto bruto em OcorrenciaRelatoDto. */
export function createOcorrenciaRelatoDto(raw = {}) {
  return {
    rel_id: raw.rel_id != null ? String(raw.rel_id) : '',
    prf_id: raw.prf_id != null ? String(raw.prf_id) : '',
    rel_tipo: raw.rel_tipo != null ? String(raw.rel_tipo) : '',
    rel_gravidade: raw.rel_gravidade != null ? String(raw.rel_gravidade) : 'Moderado',
    rel_descricao: raw.rel_descricao != null ? String(raw.rel_descricao) : null,
    rel_latitude: raw.rel_latitude != null && Number.isFinite(Number(raw.rel_latitude)) ? Number(raw.rel_latitude) : 0.0,
    rel_longitude: raw.rel_longitude != null && Number.isFinite(Number(raw.rel_longitude)) ? Number(raw.rel_longitude) : 0.0,
    rel_foto_url: raw.rel_foto_url != null ? String(raw.rel_foto_url) : null,
    rel_data_hora: raw.rel_data_hora != null ? String(raw.rel_data_hora) : '',
    rel_status: raw.rel_status != null ? String(raw.rel_status) : null,
    rel_score_antifraude: raw.rel_score_antifraude != null && Number.isFinite(Number(raw.rel_score_antifraude)) ? Number(raw.rel_score_antifraude) : null,
    rel_status_validacao: raw.rel_status_validacao != null ? String(raw.rel_status_validacao) : null,
    rel_motivo_antifraude: raw.rel_motivo_antifraude != null ? String(raw.rel_motivo_antifraude) : null,
  }
}

/** Normaliza um objeto bruto em AbrigoEmergenciaDto. */
export function createAbrigoEmergenciaDto(raw = {}) {
  return {
    abr_id: raw.abr_id != null ? String(raw.abr_id) : '',
    abr_nome: raw.abr_nome != null ? String(raw.abr_nome) : '',
    abr_cidade: raw.abr_cidade != null ? String(raw.abr_cidade) : '',
    abr_endereco: raw.abr_endereco != null ? String(raw.abr_endereco) : '',
    abr_latitude: raw.abr_latitude != null && Number.isFinite(Number(raw.abr_latitude)) ? Number(raw.abr_latitude) : 0.0,
    abr_longitude: raw.abr_longitude != null && Number.isFinite(Number(raw.abr_longitude)) ? Number(raw.abr_longitude) : 0.0,
    abr_capacidade: raw.abr_capacidade != null && Number.isFinite(Number(raw.abr_capacidade)) ? Number(raw.abr_capacidade) : 0,
    abr_ocupacao: raw.abr_ocupacao != null && Number.isFinite(Number(raw.abr_ocupacao)) ? Number(raw.abr_ocupacao) : 0,
    abr_status: raw.abr_status != null ? String(raw.abr_status) : 'disponivel',
    abr_telefone: raw.abr_telefone != null ? String(raw.abr_telefone) : null,
    abr_responsavel: raw.abr_responsavel != null ? String(raw.abr_responsavel) : null,
  }
}

/** Normaliza um objeto bruto em AlertaDefesaCivilDto. */
export function createAlertaDefesaCivilDto(raw = {}) {
  return {
    ale_id: raw.ale_id != null ? String(raw.ale_id) : '',
    ale_titulo: raw.ale_titulo != null ? String(raw.ale_titulo) : '',
    ale_mensagem: raw.ale_mensagem != null ? String(raw.ale_mensagem) : '',
    ale_severidade: raw.ale_severidade != null ? String(raw.ale_severidade) : 'Moderado',
    ale_cidade: raw.ale_cidade != null ? String(raw.ale_cidade) : null,
    ale_bairro: raw.ale_bairro != null ? String(raw.ale_bairro) : null,
    ale_latitude: raw.ale_latitude != null && Number.isFinite(Number(raw.ale_latitude)) ? Number(raw.ale_latitude) : null,
    ale_longitude: raw.ale_longitude != null && Number.isFinite(Number(raw.ale_longitude)) ? Number(raw.ale_longitude) : null,
    ale_raio_km: raw.ale_raio_km != null && Number.isFinite(Number(raw.ale_raio_km)) ? Number(raw.ale_raio_km) : null,
    ale_ativo: raw.ale_ativo != null ? Boolean(raw.ale_ativo) : true,
    created_at: raw.created_at != null ? String(raw.created_at) : '',
  }
}
