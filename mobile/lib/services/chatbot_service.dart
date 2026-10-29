import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

/// Serviço responsável por toda a comunicação com a IA Gemini
/// via o pacote [firebase_ai] (backend Vertex AI gerido pelo Firebase).
///
/// Arquitectura:
/// - Instancia [GenerativeModel] usando [FirebaseAI.vertexAI(location: 'global')]
///   que é a assinatura correcta da versão 3.12.2 do pacote.
/// - Mantém uma [ChatSession] com histórico, garantindo contexto entre turnos.
class ChatbotService {
  GenerativeModel? _model;
  ChatSession? _chat;

  // ── System Prompt ─────────────────────────────────────────────────────────
  static const String _systemPrompt =
      'Você é Nimbo, o assistente virtual do SMDN — Sistema de Monitorização '
      'de Desastres Naturais. O SMDN é um aplicativo mobile que permite a '
      'cidadãos reportar ocorrências de desastres naturais como enchentes, '
      'deslizamentos, vendavais, incêndios e outros eventos climáticos extremos. '
      '\n\nSua missão é:\n'
      '1. Orientar cidadãos sobre como usar o app para reportar ocorrências.\n'
      '2. Fornecer informações sobre procedimentos de segurança em desastres.\n'
      '3. Informar sobre alertas e avisos de emergência.\n'
      '4. Auxiliar com dúvidas sobre desastres naturais e proteção civil.\n'
      '\nIMPORTANTE: Se alguém estiver em perigo imediato, instrua sempre a '
      'ligar para: 192 (SAMU), 193 (Bombeiros), 190 (Polícia) ou 199 (Defesa Civil).\n'
      '\nResponda sempre em português do Brasil, com empatia, clareza e '
      'objetividade. Seja conciso (máximo 3–4 parágrafos por resposta).';

  // ── Construtor ────────────────────────────────────────────────────────────
  ChatbotService();

  Future<void> _initModel() async {
    if (_model != null && _chat != null) return;

    // FirebaseAI.vertexAI() aceita location como parâmetro directo (não .instanceFor).
    // 'global' disponibiliza os modelos mais recentes sem restrição regional.
    _model = FirebaseAI.vertexAI(location: 'global').generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 600,
      ),
    );

    // Inicia a sessão com a mensagem de boas-vindas já no histórico
    _chat = _model!.startChat(
      history: [
        Content.model([
          TextPart(
            'Olá, meu nome é Nimbo. Te ajudarei aqui no chat. '
            'Como quer começar?',
          ),
        ]),
      ],
    );
  }

  // ── API Pública ───────────────────────────────────────────────────────────

  /// Envia [userMessage] ao modelo e retorna a resposta em texto.
  ///
  /// Lança [Exception] com a mensagem original do Firebase caso a chamada falhe.
  Future<String> sendMessage(String userMessage) async {
    try {
      await _initModel();
      final response = await _chat!.sendMessage(Content.text(userMessage));
      final text = response.text;

      if (text == null || text.trim().isEmpty) {
        throw Exception('Resposta vazia recebida do servidor.');
      }

      return text.trim();
    } catch (e, stack) {
      debugPrint('[ChatbotService] Erro: $e');
      debugPrint('[ChatbotService] Stack: $stack');
      rethrow;
    }
  }

  /// Liberta recursos (reservado para uso futuro).
  void dispose() {}
}
