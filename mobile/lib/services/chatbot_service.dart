import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Serviço responsável por toda a comunicação com a IA Gemini (Nimbo)
/// via o pacote [firebase_ai] (backend Vertex AI gerido pelo Firebase).
class ChatbotService {
  GenerativeModel? _model;
  ChatSession? _chat;

  final Duration timeout;
  final int maxRetries;
  final Duration retryDelay;
  final Future<String?> Function(String userMessage)? transportOverride;

  // ── System Prompt ─────────────────────────────────────────────────────────
  static const String _systemPrompt =
      'Você é Nimbo, o assistente virtual do PREVER — Plataforma de Resiliência '
      'e Vigilância de Eventos de Risco. O PREVER é um aplicativo mobile que '
      'permite a cidadãos reportar ocorrências de desastres naturais como '
      'enchentes, alagamentos, deslizamentos, vendavais, incêndios e outros '
      'eventos climáticos extremos, além de localizar abrigos e alertas próximos.'
      '\n\nSua missão é:\n'
      '1. Orientar cidadãos sobre como usar o app para reportar ocorrências e SOS.\n'
      '2. Fornecer informações claras sobre procedimentos de segurança em desastres.\n'
      '3. Informar sobre alertas, abrigos de emergência e avisos oficiais.\n'
      '4. Auxiliar com dúvidas sobre desastres naturais e proteção civil.\n'
      '\nIMPORTANTE: Se alguém estiver em perigo imediato, instrua sempre a '
      'ligar para: 192 (SAMU), 193 (Bombeiros), 190 (Polícia) ou 199 (Defesa Civil).\n'
      '\nResponda sempre em português do Brasil, com empatia, clareza e '
      'objetividade. Seja conciso (máximo 3–4 parágrafos por resposta).';

  ChatbotService({
    this.timeout = const Duration(seconds: 25),
    this.maxRetries = 1,
    this.retryDelay = const Duration(milliseconds: 900),
    this.transportOverride,
  });

  Future<void> _initModel() async {
    if (_model != null && _chat != null) return;

    if (Firebase.apps.isEmpty) {
      throw StateError('Firebase não inicializado para o Nimbo.');
    }

    _model = FirebaseAI.vertexAI(location: 'global').generativeModel(
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(_systemPrompt),
      generationConfig: GenerationConfig(
        temperature: 0.5,
        maxOutputTokens: 2048,
      ),
    );

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

  static bool isTransientError(Object error) {
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
        text.contains('failed host lookup') ||
        text.contains('deadline') ||
        text.contains('timeout');
  }

  static String friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'O Nimbo demorou mais que o esperado para responder. Tente enviar novamente.';
    }
    final text = error.toString().toLowerCase();
    if (text.contains('429') ||
        text.contains('quota') ||
        text.contains('resource-exhausted') ||
        text.contains('resource_exhausted')) {
      return 'O Nimbo está recebendo muitas mensagens agora. Aguarde alguns segundos e tente novamente.';
    }
    if (text.contains('app check') || text.contains('appcheck')) {
      return 'Verificação de segurança do dispositivo pendente para o Nimbo. Tente novamente em instantes.';
    }
    if (text.contains('network') ||
        text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('connection')) {
      return 'Sem conexão estável com a internet. Verifique sua rede e tente novamente.';
    }
    if (text.contains('resposta vazia')) {
      return 'O Nimbo não conseguiu formular a resposta completa. Tente reformular sua pergunta.';
    }
    return 'O Nimbo está temporariamente indisponível. Tente novamente em instantes.';
  }

  Future<String> _executeOnce(String cleanMessage) async {
    if (transportOverride != null) {
      final raw = await transportOverride!(cleanMessage).timeout(timeout);
      final text = raw?.trim() ?? '';
      if (text.isEmpty) {
        throw Exception('Resposta vazia recebida do servidor.');
      }
      return text;
    }

    await _initModel();
    final response = await _chat!
        .sendMessage(Content.text(cleanMessage))
        .timeout(timeout);
    final text = response.text?.trim() ?? '';

    if (text.isEmpty) {
      throw Exception('Resposta vazia recebida do servidor.');
    }

    return text;
  }

  /// Envia [userMessage] ao modelo com timeout e retry automático em falhas transitórias.
  Future<String> sendMessage(String userMessage) async {
    final cleanMessage = userMessage.trim();
    if (cleanMessage.isEmpty) {
      throw ArgumentError('Digite uma mensagem para o Nimbo.');
    }

    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await _executeOnce(cleanMessage);
      } catch (e, stack) {
        lastError = e;
        debugPrint('[ChatbotService] Tentativa ${attempt + 1} falhou: $e');
        debugPrint('[ChatbotService] Stack: $stack');

        if (attempt < maxRetries && isTransientError(e)) {
          await Future<void>.delayed(retryDelay * (attempt + 1));
          continue;
        }
        break;
      }
    }

    throw lastError ?? Exception('Falha ao consultar o Nimbo.');
  }

  /// Liberta recursos da sessão atual.
  void dispose() {
    _chat = null;
    _model = null;
  }
}
