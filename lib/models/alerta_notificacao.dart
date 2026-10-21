import 'dart:convert';

/// Apenas os campos públicos do alerta são enviados ao celular.
class AlertaNotificacao {
  final String id;
  final String titulo;
  final String descricao;
  final String cidade;
  final String bairro;
  final String severidade;

  const AlertaNotificacao({
    required this.id,
    required this.titulo,
    required this.descricao,
    this.cidade = '',
    this.bairro = '',
    this.severidade = '',
  });

  static AlertaNotificacao? fromData(Map<String, dynamic> data) {
    if (data['kind'] != 'alerta_web') return null;
    String campo(String nome) => data[nome]?.toString().trim() ?? '';
    if (campo('alerta_id').isEmpty ||
        campo('titulo').isEmpty ||
        campo('descricao').isEmpty) {
      return null;
    }
    return AlertaNotificacao(
      id: campo('alerta_id'),
      titulo: campo('titulo'),
      descricao: campo('descricao'),
      cidade: campo('cidade'),
      bairro: campo('bairro'),
      severidade: campo('severidade'),
    );
  }

  static AlertaNotificacao? fromPayload(String? payload) {
    if (payload == null) return null;
    try {
      final value = jsonDecode(payload);
      return value is Map<String, dynamic> ? fromData(value) : null;
    } catch (_) {
      return null;
    }
  }

  String toPayload() => jsonEncode({
    'kind': 'alerta_web',
    'alerta_id': id,
    'titulo': titulo,
    'descricao': descricao,
    'cidade': cidade,
    'bairro': bairro,
    'severidade': severidade,
  });

  // Determinístico entre execuções: atualizações do mesmo alerta não empilham.
  int get notificationId => utf8
      .encode(id)
      .fold<int>(0, (hash, byte) => ((hash * 31) + byte) & 0x7fffffff);
}
