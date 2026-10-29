// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.
// Source: shared/schema/domain.schema.json
// Generator: scripts/generate-shared-contracts.mjs

export const SUPABASE_TABLES = Object.freeze({
  PERFIS: 'perfis',
  RELATOS: 'relatos',
  ALERTAS: 'alertas',
  ABRIGOS: 'abrigos',
  ABRIGO_OCUPANTES: 'abrigo_ocupantes',
  ABRIGO_ESTOQUE: 'abrigo_estoque',
  ABRIGO_PEDIDOS: 'abrigo_pedidos',
  SOLICITACOES_ACESSO_WEB: 'solicitacoes_acesso_web',
  AUDITORIA_LOGS: 'auditoria_logs',
  ATIVIDADES_USUARIO: 'atividades_usuario',
  TIPOS_DESASTRE: 'tipos_desastre',
})

export const SUPABASE_STORAGE_BUCKETS = Object.freeze({
  FOTOS_RELATOS: 'fotos_relatos',
  AVATARS: 'avatars',
})

export const SUPABASE_EDGE_FUNCTIONS = Object.freeze({
  APPROVE_WEB_ACCESS_REQUEST: 'approve-web-access-request',
  SMDN_AI: 'smdn-ai',
})

export const SUPABASE_RPCS = Object.freeze({
  ADMIN_UPDATE_USER_PROFILE: 'admin_update_user_profile',
  ADMIN_RESET_USER_PROFILE: 'admin_reset_user_profile',
  REGISTER_USER_ACTIVITY: 'registrar_atividade_usuario',
})
