// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.
// Source: shared/schema/domain.schema.json
// Generator: scripts/generate-shared-contracts.mjs

export type UserRole = 'admin' | 'administrador' | 'defesa_civil' | 'bombeiros' | 'funcionario' | 'agente' | 'instituicao' | 'shelter_manager' | 'cidadao' | 'pendente';

export type SeverityLevel = 'Crítico' | 'Grave' | 'Moderado';

export type ShelterStatus = 'disponivel' | 'quase_lotado' | 'lotado' | 'inativo';

export type OccurrenceValidationStatus = 'legitimo' | 'pendente_revisao' | 'rejeitado';

export interface WebPermissions {
  dashboard: boolean;
  reportar: boolean;
  ocorrencias: boolean;
  relatorios: boolean;
  validacao: boolean;
  auditoria: boolean;
  usuarios?: boolean;
  admin?: boolean;
}

/** DTO canônico de perfil de usuário (tabela perfis). */
export interface PerfilUsuarioDto {
  prf_id: string;
  prf_nome: string;
  prf_cpf?: string | null;
  prf_rg?: string | null;
  prf_telefone?: string | null;
  prf_email_contato?: string | null;
  prf_tipo: UserRole;
  prf_instituicao?: string | null;
  prf_acesso_web: boolean;
  prf_admin_web: boolean;
  prf_avatar_url?: string | null;
  prf_abrigo_id?: string | null;
  prf_ultimo_login_web?: string | null;
  created_at?: string | null;
}

/** DTO canônico de relato/ocorrência georreferenciada (tabela relatos). */
export interface OcorrenciaRelatoDto {
  rel_id: string;
  prf_id: string;
  rel_tipo: string;
  rel_gravidade: SeverityLevel;
  rel_descricao?: string | null;
  rel_latitude: number;
  rel_longitude: number;
  rel_foto_url?: string | null;
  rel_data_hora: string;
  rel_status?: string | null;
  rel_score_antifraude?: number | null;
  rel_status_validacao?: OccurrenceValidationStatus | null;
  rel_motivo_antifraude?: string | null;
}

/** DTO canônico de abrigo humanitário (tabela abrigos). */
export interface AbrigoEmergenciaDto {
  abr_id: string;
  abr_nome: string;
  abr_cidade: string;
  abr_endereco: string;
  abr_latitude: number;
  abr_longitude: number;
  abr_capacidade: number;
  abr_ocupacao: number;
  abr_status: ShelterStatus;
  abr_telefone?: string | null;
  abr_responsavel?: string | null;
}

/** DTO canônico de alerta público da Defesa Civil (tabela alertas). */
export interface AlertaDefesaCivilDto {
  ale_id: string;
  ale_titulo: string;
  ale_mensagem: string;
  ale_severidade: SeverityLevel;
  ale_cidade?: string | null;
  ale_bairro?: string | null;
  ale_latitude?: number | null;
  ale_longitude?: number | null;
  ale_raio_km?: number | null;
  ale_ativo: boolean;
  created_at: string;
}

export type PerfilUsuario = PerfilUsuarioDto;
export type OcorrenciaRelato = OcorrenciaRelatoDto;
export type AbrigoEmergencia = AbrigoEmergenciaDto;
export type AlertaDefesaCivil = AlertaDefesaCivilDto;
