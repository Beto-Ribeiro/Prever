import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_ai/firebase_ai.dart';
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
      motivoClassificacao: 'Erro na análise: $motivo. '
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
///
/// Analisa a coerência interna do relato verificando:
///   - Tipo do desastre vs. descrição textual
///   - Gravidade declarada vs. evidências visuais
///   - Conteúdo da imagem vs. contexto do evento
///   - Plausibilidade geral (ex.: receita de bolo num relato de inundação)
///
/// Uso:
/// ```dart
/// final resultado = await AntiFraudeService().analisarRelato(
///   tipoDesastre: 'Alagamento',
///   nivelGravidade: 'Severa',
///   descricao: descricaoController.text,
///   latitude: localizacaoSelecionada!.latitude,
///   longitude: localizacaoSelecionada!.longitude,
///   imagemBytes: imagemBytes,
///   mimeTypeImagem: 'image/jpeg',
/// );
/// ```
class AntiFraudeService {
  GenerativeModel? _model;

  // ── System prompt ───────────────────────────────────────────────────────────
  static const String _systemPrompt =
      'Você é um sistema especializado em detecção de fraudes em relatos de '
      'desastres naturais. Sua missão é analisar relatos enviados por cidadãos '
      'e determinar se são legítimos ou potencialmente fraudulentos.\n\n'
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
      'antes ou depois, sem blocos de código markdown, sem explicações fora '
      'do JSON. Use exatamente este formato:\n'
      '{"legitimo":true,"score_autenticidade":0.95,"motivo":"Explicação concisa"}';


  // ── Inicialização do modelo ─────────────────────────────────────────────────
  Future<void> _initModel() async {
    if (_model != null) return;
    _model = FirebaseAI.vertexAI(location: 'global').generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.2, // baixo = determinístico, mas evita resposta vazia
        maxOutputTokens: 512,
        // NÃO usar responseMimeType: 'application/json' — não suportado
        // em todas as configs do Vertex AI via Firebase web.
        // O prompt já instrui o modelo a retornar JSON puro.
      ),
    );
  }

  // ── API Pública ─────────────────────────────────────────────────────────────

  /// Analisa um relato e retorna o resultado antifraude.
  ///
  /// [tipoDesastre]    - ex.: 'Alagamento', 'Tornado', 'Desabamento', 'Chuva Forte'
  /// [nivelGravidade]  - ex.: 'Leve', 'Moderada', 'Severa'
  /// [descricao]       - texto livre digitado pelo usuário (pode ser vazio)
  /// [latitude]        - coordenada geográfica do evento
  /// [longitude]       - coordenada geográfica do evento
  /// [imagemBytes]     - bytes da imagem anexada (obrigatório no fluxo atual)
  /// [mimeTypeImagem]  - ex.: 'image/jpeg', 'image/png' (padrão: 'image/jpeg')
  Future<ResultadoAntifraude> analisarRelato({
    required String tipoDesastre,
    required String nivelGravidade,
    required String descricao,
    required double latitude,
    required double longitude,
    required Uint8List imagemBytes,
    String mimeTypeImagem = 'image/jpeg',
  }) async {
    try {
      await _initModel();

      // Monta o prompt textual com todos os metadados do relato
      final promptTexto = _montarPrompt(
        tipoDesastre: tipoDesastre,
        nivelGravidade: nivelGravidade,
        descricao: descricao,
        latitude: latitude,
        longitude: longitude,
      );

      // Parte visual: envia a imagem como InlineDataPart para análise multimodal
      final parteImagem = InlineDataPart(mimeTypeImagem, imagemBytes);
      final parteTexto = TextPart(promptTexto);

      final resposta = await _model!.generateContent([
        Content.multi([parteTexto, parteImagem]),
      ]);

      return _parsearResposta(resposta.text);
    } catch (e, stack) {
      debugPrint('[AntiFraudeService] Erro ao analisar relato: $e');
      debugPrint('[AntiFraudeService] Stack: $stack');
      return ResultadoAntifraude.erro(e.toString());
    }
  }

  // ── Helpers privados ────────────────────────────────────────────────────────

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

  ResultadoAntifraude _parsearResposta(String? textoResposta) {
    if (textoResposta == null || textoResposta.trim().isEmpty) {
      return ResultadoAntifraude.erro('Resposta vazia recebida do modelo');
    }

    try {
      // Remove possíveis blocos markdown caso o modelo ignore a instrução
      String json = textoResposta.trim();
      if (json.startsWith('```')) {
        json = json.replaceAll(RegExp(r'```[a-z]*\n?'), '').trim();
      }

      final Map<String, dynamic> dados = jsonDecode(json);

      final bool legitimo = dados['legitimo'] as bool? ?? false;
      final double score =
          (dados['score_autenticidade'] as num?)?.toDouble() ?? 0.0;
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
      debugPrint('[AntiFraudeService] Resposta recebida: $textoResposta');
      return ResultadoAntifraude.erro(
          'Formato de resposta inválido: $textoResposta');
    }
  }

  /// Libera recursos e força reinicialização na próxima chamada.
  void dispose() {
    _model = null;
  }
}
