import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prever/services/antifraude_service.dart';
import 'package:prever/services/chatbot_service.dart';

void main() {
  group('ChatbotService (Nimbo Mobile)', () {
    test('retorna resposta limpa e faz retry automático em erro 429', () async {
      var chamadas = 0;
      final service = ChatbotService(
        retryDelay: const Duration(milliseconds: 5),
        maxRetries: 1,
        transportOverride: (msg) async {
          chamadas++;
          if (chamadas == 1) {
            throw Exception('429 RESOURCE_EXHAUSTED: quota exceeded');
          }
          return '  Procure um local elevado e acione 199 (Defesa Civil).  ';
        },
      );

      final resposta = await service.sendMessage('Está alagando minha rua');
      expect(chamadas, 2);
      expect(
        resposta,
        'Procure um local elevado e acione 199 (Defesa Civil).',
      );
    });

    test('aplica timeout quando provedor demora além do limite', () async {
      final service = ChatbotService(
        timeout: const Duration(milliseconds: 30),
        maxRetries: 0,
        transportOverride: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return 'Tarde demais';
        },
      );

      await expectLater(
        () => service.sendMessage('Olá'),
        throwsA(isA<TimeoutException>()),
      );

      expect(
        ChatbotService.friendlyError(TimeoutException('timeout')),
        contains('demorou mais que o esperado'),
      );
      expect(
        ChatbotService.friendlyError(Exception('429 quota')),
        contains('muitas mensagens'),
      );
      expect(
        ChatbotService.friendlyError(Exception('AppCheck token invalid')),
        contains('Verificação de segurança'),
      );
    });
  });

  group('AntiFraudeService (Gemini Multimodal Mobile)', () {
    final fakeBytes = Uint8List.fromList([1, 2, 3, 4]);

    test(
      'aprova relato com score >= 0.80 mesmo com bloco markdown ao redor',
      () async {
        final service = AntiFraudeService(
          generatorOverride: (prompt, bytes, mime) async {
            expect(prompt, contains('Alagamento'));
            expect(mime, 'image/jpeg');
            return '''
```json
{"legitimo": true, "score_autenticidade": 0.92, "motivo": "Foto coerente com rua alagada."}
```
''';
          },
        );

        final resultado = await service.analisarRelato(
          tipoDesastre: 'Alagamento',
          nivelGravidade: 'Severa',
          descricao: 'Água cobrindo a calçada',
          latitude: -23.55,
          longitude: -46.63,
          imagemBytes: fakeBytes,
        );

        expect(resultado.status, StatusAntifraude.legitimo);
        expect(resultado.precisaRevisaoAdmin, isFalse);
        expect(resultado.statusBanco, 'aprovado');
        expect(resultado.prioridadeBanco, 'normal');
      },
    );

    test(
      'marca relato com score < 0.80 como suspeito para revisão humana',
      () async {
        final service = AntiFraudeService(
          generatorOverride: (_, _, _) async =>
              '{"legitimo": true, "score_autenticidade": 0.79, "motivo": "Evidência visual ambígua."}',
        );

        final resultado = await service.analisarRelato(
          tipoDesastre: 'Desabamento',
          nivelGravidade: 'Moderada',
          descricao: 'Muro trincado',
          latitude: -23.55,
          longitude: -46.63,
          imagemBytes: fakeBytes,
        );

        expect(resultado.status, StatusAntifraude.suspeitoFraude);
        expect(resultado.precisaRevisaoAdmin, isTrue);
        expect(resultado.statusBanco, 'pendente_revisao');
        expect(resultado.prioridadeBanco, 'baixa');
      },
    );

    test(
      'faz retry em falha transitória 503 e entra em modo fail-safe se ocorrer timeout',
      () async {
        var tentativas = 0;
        final recuperavel = AntiFraudeService(
          retryDelay: const Duration(milliseconds: 5),
          maxRetries: 1,
          generatorOverride: (_, _, _) async {
            tentativas++;
            if (tentativas == 1) {
              throw Exception('503 Service Unavailable');
            }
            return '{"legitimo": true, "score_autenticidade": 0.88, "motivo": "Coerente."}';
          },
        );

        final ok = await recuperavel.analisarRelato(
          tipoDesastre: 'Chuva Forte',
          nivelGravidade: 'Leve',
          descricao: 'Chuva forte na avenida',
          latitude: -23.5,
          longitude: -46.6,
          imagemBytes: fakeBytes,
        );
        expect(tentativas, 2);
        expect(ok.status, StatusAntifraude.legitimo);

        final comTimeout = AntiFraudeService(
          timeout: const Duration(milliseconds: 25),
          maxRetries: 0,
          generatorOverride: (_, _, _) async {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            return '{}';
          },
        );

        final fallback = await comTimeout.analisarRelato(
          tipoDesastre: 'Alagamento',
          nivelGravidade: 'Severa',
          descricao: '',
          latitude: -23.5,
          longitude: -46.6,
          imagemBytes: fakeBytes,
        );
        expect(fallback.status, StatusAntifraude.erroAnalise);
        expect(fallback.precisaRevisaoAdmin, isTrue);
        expect(fallback.statusBanco, 'pendente_revisao');
        expect(fallback.motivoClassificacao, contains('Tempo limite excedido'));
      },
    );
  });
}
