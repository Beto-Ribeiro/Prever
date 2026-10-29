// AUTO-GENERATED FILE — DO NOT EDIT MANUALLY.
// Source: shared/schema/domain.schema.json
// Generator: scripts/generate-shared-contracts.mjs

class PreverTables {
  const PreverTables._();
  static const String perfis = 'perfis';
  static const String relatos = 'relatos';
  static const String alertas = 'alertas';
  static const String abrigos = 'abrigos';
  static const String abrigoOcupantes = 'abrigo_ocupantes';
  static const String abrigoEstoque = 'abrigo_estoque';
  static const String abrigoPedidos = 'abrigo_pedidos';
  static const String solicitacoesAcessoWeb = 'solicitacoes_acesso_web';
  static const String auditoriaLogs = 'auditoria_logs';
  static const String atividadesUsuario = 'atividades_usuario';
  static const String tiposDesastre = 'tipos_desastre';
}

class PreverStorageBuckets {
  const PreverStorageBuckets._();
  static const String fotosRelatos = 'fotos_relatos';
  static const String avatars = 'avatars';
}

class PreverEdgeFunctions {
  const PreverEdgeFunctions._();
  static const String approveWebAccessRequest = 'approve-web-access-request';
  static const String smdnAi = 'smdn-ai';
}

class PreverAntifraudConfig {
  const PreverAntifraudConfig._();
  static const double minLegitimateScore = 0.8;
  static const String modelName = 'gemini-2.5-flash-lite';
  static const String fallbackStatus = 'pendente_revisao';
}

/// DTO canônico de perfil de usuário (tabela perfis).
class PerfilUsuarioDto {
  final String prfId;
  final String prfNome;
  final String? prfCpf;
  final String? prfRg;
  final String? prfTelefone;
  final String? prfEmailContato;
  final String prfTipo;
  final String? prfInstituicao;
  final bool prfAcessoWeb;
  final bool prfAdminWeb;
  final String? prfAvatarUrl;
  final String? prfAbrigoId;
  final String? prfUltimoLoginWeb;
  final String? createdAt;

  const PerfilUsuarioDto({
    required this.prfId,
    required this.prfNome,
    this.prfCpf,
    this.prfRg,
    this.prfTelefone,
    this.prfEmailContato,
    required this.prfTipo,
    this.prfInstituicao,
    required this.prfAcessoWeb,
    required this.prfAdminWeb,
    this.prfAvatarUrl,
    this.prfAbrigoId,
    this.prfUltimoLoginWeb,
    this.createdAt,
  });

  factory PerfilUsuarioDto.fromJson(Map<String, dynamic> json) {
    return PerfilUsuarioDto(
      prfId: json['prf_id']?.toString() ?? '',
      prfNome: json['prf_nome']?.toString() ?? '',
      prfCpf: json['prf_cpf']?.toString(),
      prfRg: json['prf_rg']?.toString(),
      prfTelefone: json['prf_telefone']?.toString(),
      prfEmailContato: json['prf_email_contato']?.toString(),
      prfTipo: json['prf_tipo']?.toString() ?? 'cidadao',
      prfInstituicao: json['prf_instituicao']?.toString(),
      prfAcessoWeb: (json['prf_acesso_web'] as bool?) ?? false,
      prfAdminWeb: (json['prf_admin_web'] as bool?) ?? false,
      prfAvatarUrl: json['prf_avatar_url']?.toString(),
      prfAbrigoId: json['prf_abrigo_id']?.toString(),
      prfUltimoLoginWeb: json['prf_ultimo_login_web']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'prf_id': prfId,
      'prf_nome': prfNome,
      'prf_cpf': prfCpf,
      'prf_rg': prfRg,
      'prf_telefone': prfTelefone,
      'prf_email_contato': prfEmailContato,
      'prf_tipo': prfTipo,
      'prf_instituicao': prfInstituicao,
      'prf_acesso_web': prfAcessoWeb,
      'prf_admin_web': prfAdminWeb,
      'prf_avatar_url': prfAvatarUrl,
      'prf_abrigo_id': prfAbrigoId,
      'prf_ultimo_login_web': prfUltimoLoginWeb,
      'created_at': createdAt,
    };
  }
}

/// DTO canônico de relato/ocorrência georreferenciada (tabela relatos).
class OcorrenciaRelatoDto {
  final String relId;
  final String prfId;
  final String relTipo;
  final String relGravidade;
  final String? relDescricao;
  final double relLatitude;
  final double relLongitude;
  final String? relFotoUrl;
  final String relDataHora;
  final String? relStatus;
  final double? relScoreAntifraude;
  final String? relStatusValidacao;
  final String? relMotivoAntifraude;

  const OcorrenciaRelatoDto({
    required this.relId,
    required this.prfId,
    required this.relTipo,
    required this.relGravidade,
    this.relDescricao,
    required this.relLatitude,
    required this.relLongitude,
    this.relFotoUrl,
    required this.relDataHora,
    this.relStatus,
    this.relScoreAntifraude,
    this.relStatusValidacao,
    this.relMotivoAntifraude,
  });

  factory OcorrenciaRelatoDto.fromJson(Map<String, dynamic> json) {
    return OcorrenciaRelatoDto(
      relId: json['rel_id']?.toString() ?? '',
      prfId: json['prf_id']?.toString() ?? '',
      relTipo: json['rel_tipo']?.toString() ?? '',
      relGravidade: json['rel_gravidade']?.toString() ?? 'Moderado',
      relDescricao: json['rel_descricao']?.toString(),
      relLatitude: (json['rel_latitude'] as num?)?.toDouble() ?? 0.0,
      relLongitude: (json['rel_longitude'] as num?)?.toDouble() ?? 0.0,
      relFotoUrl: json['rel_foto_url']?.toString(),
      relDataHora: json['rel_data_hora']?.toString() ?? '',
      relStatus: json['rel_status']?.toString(),
      relScoreAntifraude: (json['rel_score_antifraude'] as num?)?.toDouble(),
      relStatusValidacao: json['rel_status_validacao']?.toString(),
      relMotivoAntifraude: json['rel_motivo_antifraude']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rel_id': relId,
      'prf_id': prfId,
      'rel_tipo': relTipo,
      'rel_gravidade': relGravidade,
      'rel_descricao': relDescricao,
      'rel_latitude': relLatitude,
      'rel_longitude': relLongitude,
      'rel_foto_url': relFotoUrl,
      'rel_data_hora': relDataHora,
      'rel_status': relStatus,
      'rel_score_antifraude': relScoreAntifraude,
      'rel_status_validacao': relStatusValidacao,
      'rel_motivo_antifraude': relMotivoAntifraude,
    };
  }
}

/// DTO canônico de abrigo humanitário (tabela abrigos).
class AbrigoEmergenciaDto {
  final String abrId;
  final String abrNome;
  final String abrCidade;
  final String abrEndereco;
  final double abrLatitude;
  final double abrLongitude;
  final int abrCapacidade;
  final int abrOcupacao;
  final String abrStatus;
  final String? abrTelefone;
  final String? abrResponsavel;

  const AbrigoEmergenciaDto({
    required this.abrId,
    required this.abrNome,
    required this.abrCidade,
    required this.abrEndereco,
    required this.abrLatitude,
    required this.abrLongitude,
    required this.abrCapacidade,
    required this.abrOcupacao,
    required this.abrStatus,
    this.abrTelefone,
    this.abrResponsavel,
  });

  factory AbrigoEmergenciaDto.fromJson(Map<String, dynamic> json) {
    return AbrigoEmergenciaDto(
      abrId: json['abr_id']?.toString() ?? '',
      abrNome: json['abr_nome']?.toString() ?? '',
      abrCidade: json['abr_cidade']?.toString() ?? '',
      abrEndereco: json['abr_endereco']?.toString() ?? '',
      abrLatitude: (json['abr_latitude'] as num?)?.toDouble() ?? 0.0,
      abrLongitude: (json['abr_longitude'] as num?)?.toDouble() ?? 0.0,
      abrCapacidade: (json['abr_capacidade'] as num?)?.toInt() ?? 0,
      abrOcupacao: (json['abr_ocupacao'] as num?)?.toInt() ?? 0,
      abrStatus: json['abr_status']?.toString() ?? 'disponivel',
      abrTelefone: json['abr_telefone']?.toString(),
      abrResponsavel: json['abr_responsavel']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'abr_id': abrId,
      'abr_nome': abrNome,
      'abr_cidade': abrCidade,
      'abr_endereco': abrEndereco,
      'abr_latitude': abrLatitude,
      'abr_longitude': abrLongitude,
      'abr_capacidade': abrCapacidade,
      'abr_ocupacao': abrOcupacao,
      'abr_status': abrStatus,
      'abr_telefone': abrTelefone,
      'abr_responsavel': abrResponsavel,
    };
  }
}

/// DTO canônico de alerta público da Defesa Civil (tabela alertas).
class AlertaDefesaCivilDto {
  final String aleId;
  final String aleTitulo;
  final String aleMensagem;
  final String aleSeveridade;
  final String? aleCidade;
  final String? aleBairro;
  final double? aleLatitude;
  final double? aleLongitude;
  final double? aleRaioKm;
  final bool aleAtivo;
  final String createdAt;

  const AlertaDefesaCivilDto({
    required this.aleId,
    required this.aleTitulo,
    required this.aleMensagem,
    required this.aleSeveridade,
    this.aleCidade,
    this.aleBairro,
    this.aleLatitude,
    this.aleLongitude,
    this.aleRaioKm,
    required this.aleAtivo,
    required this.createdAt,
  });

  factory AlertaDefesaCivilDto.fromJson(Map<String, dynamic> json) {
    return AlertaDefesaCivilDto(
      aleId: json['ale_id']?.toString() ?? '',
      aleTitulo: json['ale_titulo']?.toString() ?? '',
      aleMensagem: json['ale_mensagem']?.toString() ?? '',
      aleSeveridade: json['ale_severidade']?.toString() ?? 'Moderado',
      aleCidade: json['ale_cidade']?.toString(),
      aleBairro: json['ale_bairro']?.toString(),
      aleLatitude: (json['ale_latitude'] as num?)?.toDouble(),
      aleLongitude: (json['ale_longitude'] as num?)?.toDouble(),
      aleRaioKm: (json['ale_raio_km'] as num?)?.toDouble(),
      aleAtivo: (json['ale_ativo'] as bool?) ?? true,
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'ale_id': aleId,
      'ale_titulo': aleTitulo,
      'ale_mensagem': aleMensagem,
      'ale_severidade': aleSeveridade,
      'ale_cidade': aleCidade,
      'ale_bairro': aleBairro,
      'ale_latitude': aleLatitude,
      'ale_longitude': aleLongitude,
      'ale_raio_km': aleRaioKm,
      'ale_ativo': aleAtivo,
      'created_at': createdAt,
    };
  }
}
