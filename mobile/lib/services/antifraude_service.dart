import 'dart:async';
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum: status retornado pelo filtro antifraude
// ─────────────────────────────────────────────────────────────────────────────
enum StatusAntifraude {
  /// Relato avaliado como autêntico — segue para o banco normalmente.
  legitimo,

  /// Relato com inconsistências — vai para fila de revisão humana.
  suspeitoFraude,

  /// Análise não pôde ser concluída — tratado como suspeito por precaução.
  erroAnalise,
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de resultado da análise antifraude
// ─────────────────────────────────────────────────────────────────────────────
class ResultadoAntifraude {
  /// Status final da análise.
  final StatusAntifraude status;

  /// Pontuação de autenticidade de 0.0 (fraude total) a 1.0 (totalmente legítimo).
  final double scoreAutenticidade;

  /// Explicação detalhada gerada pelo Gemini sobre o motivo da classificação.
  final String motivoClassificacao;

  /// Indica se um admin precisa revisar antes do relato ser publicado.
  bool get precisaRevisaoAdmin => status != StatusAntifraude.legitimo;

  /// Nível de prioridade a ser gravado no banco.
  String get prioridadeBanco {
    switch (status) {
      case StatusAntifraude.legitimo:
        return 'normal';
      case StatusAntifraude.suspeitoFraude:
      case StatusAntifraude.erroAnalise:
        return 'baixa';
    }
  }

  /// Status textual para gravar na coluna do banco de dados.
  String get statusBanco {
    switch (status) {
      case StatusAntifraude.legitimo:
        return 'aprovado';
      case StatusAntifraude.suspeitoFraude:
        return 'pendente_revisao';
      case StatusAntifraude.erroAnalise:
        return 'pendente_revisao';
    }
  }

  const ResultadoAntifraude({
    required this.status,
    required this.scoreAutenticidade,
    required this.motivoClassificacao,
  });

  /// Cria um resultado de erro padrão para usar quando a IA falha.
  factory ResultadoAntifraude.erro(String motivo) {
    return ResultadoAntifraude(
      status: StatusAntifraude.erroAnalise,
      scoreAutenticidade: 0.0,
      motivoClassificacao:
          'Erro na análise: $motivo. '
          'Relato marcado para revisão humana por precaução.',
    );
  }

  @override
  String toString() =>
      'ResultadoAntifraude(status: $status, score: $scoreAutenticidade, '
      'motivo: $motivoClassificacao)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Serviço: AntiFraudeService
// ─────────────────────────────────────────────────────────────────────────────

/// Filtro antifraude baseado em IA multimodal (Gemini via Firebase AI).
class AntiFraudeService {
  GenerativeModel? _model;

  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final Future<String?> Function(
    String promptTexto,
    Uint8List imagemBytes,
    String mimeTypeImagem,
  )?
  generatorOverride;

  AntiFraudeService({
    this.timeout = const Duration(seconds: 30),
    this.maxRetries = 1,
    this.retryDelay = const Duration(milliseconds: 900),
    this.generatorOverride,
  });

  // ── System prompt ───────────────────────────────────────────────────────────
  static const String _systemPrompt =
      'Você é um sistema especializado em detecção de fraudes em relatos de '
      'desastres naturais da plataforma PREVER. Sua missão é analisar relatos '
      'enviados por cidadãos e determinar se são legítimos ou potencialmente '
      'fraudulentos.\n\n'
      'Você deve avaliar a COERÊNCIA entre:\n'
      '1. Tipo do desastre e a descrição textual fornecida\n'
      '2. Nível de gravidade declarado e as evidências visuais na foto\n'
      '3. Conteúdo da imagem e o contexto do evento relatado\n'
      '4. Plausibilidade geral do relato\n\n'
      'Exemplos de FRAUDE:\n'
      '- Relato de inundação severa com foto de anúncio de produto\n'
      '- Relato de tornado com descrição de terremoto\n'
      '- Relato de deslizamento com foto de pôr do sol tranquilo\n'
      '- Descrição completamente irrelevante para o tipo de desastre\n\n'
      'Exemplos de LEGÍTIMO:\n'
      '- Relato de alagamento com foto de ruas inundadas\n'
      '- Relato de chuva forte com descrição de acúmulo de água\n'
      '- Foto com contexto plausível mesmo que não seja perfeita\n\n'
      'IMPORTANTE: Seja rigoroso mas justo. Fotos de celular em desastres '
      'reais podem ser tremidas, escuras ou com ângulo ruim. '
      'O critério principal é a INCOERÊNCIA FLAGRANTE entre os campos.\n\n'
      'FORMATO DE RESPOSTA OBRIGATÓRIO:\n'
      'Responda EXCLUSIVAMENTE com um objeto JSON válido, sem nenhum texto '
      'antes ou depois, sem blocos de código markdown. O JSON deve conter:\n'
      '- "legitimo": boolean (true se for coerente, false se for suspeito)\n'
      '- "score_autenticidade": número de 0.0 a 1.0\n'
      '- "motivo": string contendo uma explicação de forma humana, clara e empática, direcionada diretamente ao usuário (ex: "Notamos que a imagem que você enviou..."), justificando o motivo da suspeita ou aprovação.\n\n'
      'IMPORTANTE: Não copie o exemplo abaixo. Gere a sua própria análise com base na imagem e dados recebidos.\n'
      'Exemplo de saída:\n'
      '{"legitimo": false, "score_autenticidade": 0.1, "motivo": "Notamos que a foto que você enviou mostra um ambiente interno e seco, o que não condiz com o relato de rua alagada. Por favor, verifique se enviou a foto correta."}';

  // ── Inicialização do modelo ─────────────────────────────────────────────────
  Future<void> _initModel() async {
    if (_model != null) return;
    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase não inicializado para análise antifraude.');
    }
    _model = FirebaseAI.vertexAI(location: 'global').generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 2048,
        responseMimeType: kIsWeb ? null : 'application/json',
      ),
    );
  }

  static bool _isTransient(Object error) {
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('429') ||
        text.contains('503') ||
        text.contains('quota') ||
        text.contains('resource-exhausted') ||
        text.contains('resource_exhausted') ||
        text.contains('unavailable') ||
        text.contains('network') ||
        text.contains('socketexception') ||
        text.contains('timeout');
  }

  // ── API Pública ─────────────────────────────────────────────────────────────

  /// Analisa um relato e retorna o resultado antifraude (fail-safe em caso de falha).
  Future<ResultadoAntifraude> analisarRelato({
    required String tipoDesastre,
    required String nivelGravidade,
    required String descricao,
    required double latitude,
    required double longitude,
    required Uint8List imagemBytes,
    String mimeTypeImagem = 'image/jpeg',
  }) async {
    final promptTexto = _montarPrompt(
      tipoDesastre: tipoDesastre,
      nivelGravidade: nivelGravidade,
      descricao: descricao,
      latitude: latitude,
      longitude: longitude,
    );

    Object? ultimoErro;
    for (var tentativa = 0; tentativa <= maxRetries; tentativa++) {
      try {
        String? textoResposta;
        if (generatorOverride != null) {
          textoResposta = await generatorOverride!(
            promptTexto,
            imagemBytes,
            mimeTypeImagem,
          ).timeout(timeout);
        } else {
          await _initModel();
          final parteImagem = InlineDataPart(mimeTypeImagem, imagemBytes);
          final parteTexto = TextPart(promptTexto);
          final resposta = await _model!
              .generateContent([
                Content.multi([parteTexto, parteImagem]),
              ])
              .timeout(timeout);
          textoResposta = resposta.text;
        }

        return parsearResposta(textoResposta);
      } catch (e, stack) {
        ultimoErro = e;
        debugPrint(
          '[AntiFraudeService] Tentativa ${tentativa + 1} falhou: $e',
        );
        debugPrint('[AntiFraudeService] Stack: $stack');

        if (tentativa < maxRetries && _isTransient(e)) {
          await Future<void>.delayed(retryDelay * (tentativa + 1));
          continue;
        }
        break;
      }
    }

    final descricaoErro = ultimoErro is TimeoutException
        ? 'Tempo limite excedido na verificação automática'
        : 'Serviço de análise temporariamente indisponível';
    return ResultadoAntifraude.erro(descricaoErro);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _montarPrompt({
    required String tipoDesastre,
    required String nivelGravidade,
    required String descricao,
    required double latitude,
    required double longitude,
  }) {
    return '''
Analise o seguinte relato de desastre natural e determine se é legítimo ou suspeito de fraude.

=== DADOS DO RELATO ===
TIPO DO DESASTRE: $tipoDesastre
NÍVEL DE GRAVIDADE: $nivelGravidade
DESCRIÇÃO DO USUÁRIO: "${descricao.isEmpty ? '[Nenhuma descrição fornecida]' : descricao}"
LOCALIZAÇÃO: Latitude $latitude, Longitude $longitude

=== IMAGEM ANEXADA ===
[A imagem está incluída nesta requisição. Analise seu conteúdo visual.]

=== TAREFA ===
Verifique se existe COERÊNCIA entre o tipo de desastre, o nível de gravidade,
a descrição textual e o conteúdo visual da imagem.

Retorne o JSON de análise conforme o formato definido.
''';
  }

  @visibleForTesting
  ResultadoAntifraude parsearResposta(String? textoResposta) {
    if (textoResposta == null || textoResposta.trim().isEmpty) {
      return ResultadoAntifraude.erro('Resposta vazia recebida do modelo');
    }

    try {
      String json = textoResposta.trim();
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(json);
      if (match != null) {
        json = match.group(0)!;
      }

      final Map<String, dynamic> dados = jsonDecode(json);

      final double score =
          (dados['score_autenticidade'] as num?)?.toDouble() ?? 0.0;

      // Limite estrito de 80% para aprovação automática.
      final bool legitimo = score >= 0.80;

      final String motivo =
          dados['motivo'] as String? ?? 'Sem motivo retornado pelo modelo.';

      return ResultadoAntifraude(
        status: legitimo
            ? StatusAntifraude.legitimo
            : StatusAntifraude.suspeitoFraude,
        scoreAutenticidade: score.clamp(0.0, 1.0),
        motivoClassificacao: motivo,
      );
    } catch (e) {
      debugPrint('[AntiFraudeService] Erro ao parsear JSON: $e');
      return ResultadoAntifraude.erro(
        'Formato de resposta inválido da análise automática',
      );
    }
  }

  /// Libera recursos e força reinicialização na próxima chamada.
  void dispose() {
    _model = null;
  }
}
