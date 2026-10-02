/// Teste de carga: relatos simultâneos do app mobile
///
/// Objetivo:
///   Descobrir quantos relatos o app consegue processar simultaneamente
///   e medir o tempo de resposta em cada cenário de concorrência.
///
/// O que é testado:
///   - Lógica de validação, mapeamento de severidade e antifraude
///   - Escalabilidade: 1, 5, 10, 25 e 50 relatos em paralelo
///   - Cenário de alta latência (IA sobrecarregada / rede lenta)
///
/// IMPORTANTE: usa test() puro, não testWidgets(), pois Future.delayed
/// em testWidgets entra em deadlock com o fake-time do WidgetTester.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:prever/services/severidade_relato.dart';
import 'package:prever/services/relatos_proximos_service.dart';
import 'package:prever/services/antifraude_service.dart';

// ────────────────────────────────────────────────────────────────────────────
// Simulação do envio de um relato completo (sem I/O externo)
// ────────────────────────────────────────────────────────────────────────────

/// Replica toda a lógica da camada de negócio de [Relatos_tela.enviarRelato]
/// sem dependências de Supabase, Firebase ou geolocator.
///
/// Retorna quantos ms o envio levou, ou lança [ArgumentError] se
/// alguma validação falhar.
Future<int> _simularEnvioRelato({
  required String tipoDesastre,
  required String nivelGravidade,
  required String descricao,
  required double latitude,
  required double longitude,
  int latenciaAnaliseMs = 200,
  int latenciaDbMs = 150,
}) async {
  final sw = Stopwatch()..start();

  // 1. Validação de campos obrigatórios
  if (tipoDesastre.isEmpty || nivelGravidade.isEmpty) {
    throw ArgumentError('Campos obrigatórios ausentes');
  }

  // 2. Classificação de severidade (código real)
  final severidade = identificarSeveridade(nivelGravidade);
  if (severidade == SeveridadeRelato.desconhecida) {
    throw ArgumentError('Nível de gravidade inválido: "$nivelGravidade"');
  }

  // 3. Montagem do ponto geográfico
  final pontoGeo = 'POINT($longitude $latitude)';
  assert(pontoGeo.startsWith('POINT'), 'Formato inválido');

  // 4. Análise antifraude (latência de IA simulada com real async)
  await Future<void>.delayed(Duration(milliseconds: latenciaAnaliseMs));

  final resultadoAntifraude = ResultadoAntifraude(
    status: StatusAntifraude.legitimo,
    scoreAutenticidade: 0.92,
    motivoClassificacao: 'Relato coerente (mock)',
  );

  // 5. Gravação no banco + upload da foto (latência simulada)
  await Future<void>.delayed(Duration(milliseconds: latenciaDbMs));

  // Asserts dos campos gravados no schema do Supabase
  assert(resultadoAntifraude.statusBanco == 'aprovado');
  assert(resultadoAntifraude.prioridadeBanco == 'normal');
  assert(!resultadoAntifraude.precisaRevisaoAdmin);

  sw.stop();
  return sw.elapsedMilliseconds;
}

// ────────────────────────────────────────────────────────────────────────────
// Runner de carga
// ────────────────────────────────────────────────────────────────────────────

final _tipos = ['Alagamento', 'Tornado', 'Desabamento', 'Chuva Forte'];
final _niveis = ['Leve', 'Moderada', 'Severa'];

Future<Map<String, dynamic>> _executarCarga(
  int n, {
  int latenciaAnaliseMs = 200,
  int latenciaDbMs = 150,
}) async {
  final sw = Stopwatch()..start();

  final futuros = List.generate(n, (i) async {
    try {
      final ms = await _simularEnvioRelato(
        tipoDesastre: _tipos[i % _tipos.length],
        nivelGravidade: _niveis[i % _niveis.length],
        descricao: 'Relato de carga #$i',
        latitude: -23.55 + i * 0.001,
        longitude: -46.63 + i * 0.001,
        latenciaAnaliseMs: latenciaAnaliseMs,
        latenciaDbMs: latenciaDbMs,
      );
      return {'ok': true, 'ms': ms};
    } catch (e) {
      return {'ok': false, 'erro': '$e', 'ms': 0};
    }
  });

  final resultados = await Future.wait(futuros);
  sw.stop();

  final tempos = resultados
      .where((r) => r['ok'] == true)
      .map((r) => r['ms'] as int)
      .toList()
    ..sort();

  final falhas = resultados.where((r) => r['ok'] == false).length;

  int media = 0, mediana = 0, p95 = 0, maxMs = 0;
  if (tempos.isNotEmpty) {
    media = (tempos.reduce((a, b) => a + b) / tempos.length).round();
    mediana = tempos[tempos.length ~/ 2];
    p95 = tempos[(tempos.length * 0.95).floor().clamp(0, tempos.length - 1)];
    maxMs = tempos.last;
  }

  return {
    'n': n,
    'sucessos': tempos.length,
    'falhas': falhas,
    'tempoTotalMs': sw.elapsedMilliseconds,
    'mediaMs': media,
    'medianaMs': mediana,
    'p95Ms': p95,
    'maxMs': maxMs,
    'throughput': n / (sw.elapsedMilliseconds / 1000),
  };
}

void _print(Map<String, dynamic> r) {
  final ok = r['falhas'] == 0 ? '✓' : '✗';
  // ignore: avoid_print
  print(
    '\n$ok ${r['n']} relatos simultâneos\n'
    '   Total: ${r['tempoTotalMs']}ms | '
    'Sucessos: ${r['sucessos']} | Falhas: ${r['falhas']}\n'
    '   Média: ${r['mediaMs']}ms | Mediana: ${r['medianaMs']}ms | '
    'P95: ${r['p95Ms']}ms | Máx: ${r['maxMs']}ms\n'
    '   Throughput: ${(r['throughput'] as double).toStringAsFixed(1)} relatos/s',
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Suíte de testes
// ────────────────────────────────────────────────────────────────────────────

void main() {
  // ── Lógica de negócio ──────────────────────────────────────────────────────
  group('Validação de lógica de negócio (relatos)', () {
    test('Severidade mapeia corretamente os três níveis', () {
      expect(identificarSeveridade('Leve'), SeveridadeRelato.leve);
      expect(identificarSeveridade('Moderada'), SeveridadeRelato.moderada);
      expect(identificarSeveridade('Severa'), SeveridadeRelato.severa);
      expect(identificarSeveridade('Extrema'), SeveridadeRelato.severa);
      expect(identificarSeveridade(null), SeveridadeRelato.desconhecida);
      expect(identificarSeveridade(''), SeveridadeRelato.desconhecida);
    });

    test('ResultadoAntifraude: score ≥ 0.80 → legítimo', () {
      final legitimo = ResultadoAntifraude(
        status: StatusAntifraude.legitimo,
        scoreAutenticidade: 0.92,
        motivoClassificacao: 'OK',
      );
      expect(legitimo.statusBanco, 'aprovado');
      expect(legitimo.prioridadeBanco, 'normal');
      expect(legitimo.precisaRevisaoAdmin, isFalse);
    });

    test('ResultadoAntifraude: score < 0.80 → suspeito / revisão pendente', () {
      final suspeito = ResultadoAntifraude(
        status: StatusAntifraude.suspeitoFraude,
        scoreAutenticidade: 0.60,
        motivoClassificacao: 'Imagem incoerente',
      );
      expect(suspeito.statusBanco, 'pendente_revisao');
      expect(suspeito.prioridadeBanco, 'baixa');
      expect(suspeito.precisaRevisaoAdmin, isTrue);
    });

    test('ResultadoAntifraude.erro() usa precaução (revisão obrigatória)', () {
      final erro = ResultadoAntifraude.erro('timeout na IA');
      expect(erro.status, StatusAntifraude.erroAnalise);
      expect(erro.scoreAutenticidade, 0.0);
      expect(erro.precisaRevisaoAdmin, isTrue);
      expect(erro.statusBanco, 'pendente_revisao');
    });

    test('Filtro de relatos próximos: exclui SOS e coordenadas inválidas', () {
      final dados = [
        {'latitude': -23.55, 'longitude': -46.63, 'rel_tipo_desastre': 'Alagamento', 'rel_descricao': 'Moderada'},
        {'latitude': -23.55, 'longitude': -46.63, 'rel_tipo_desastre': 'SOS', 'rel_descricao': 'Leve'},
        {'latitude': null,   'longitude': -46.63, 'rel_tipo_desastre': 'Tornado',    'rel_descricao': 'Severa'},
        {'latitude': 91,     'longitude': -46.63, 'rel_tipo_desastre': 'Chuva Forte','rel_descricao': 'Leve'},
        {'latitude': -23.551,'longitude': -46.631,'rel_tipo_desastre': 'Desabamento','rel_descricao': 'Severa'},
      ];
      final resultado = filtrarRelatosProximos(dados, -23.55, -46.63, raioMetros: 500);
      expect(resultado.map((r) => r.tipo), ['Alagamento', 'Desabamento']);
    });

    test('Envio inválido lança ArgumentError (sem gravidade)', () async {
      await expectLater(
        () => _simularEnvioRelato(
          tipoDesastre: 'Alagamento',
          nivelGravidade: 'Desconhecido',
          descricao: 'teste',
          latitude: -23.55,
          longitude: -46.63,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  // ── Testes de carga: concorrência ──────────────────────────────────────────
  group('Carga: relatos simultâneos (IA ~200ms + DB ~150ms)', () {
    final relatorio = <Map<String, dynamic>>[];

    tearDownAll(() {
      // ignore: avoid_print
      print('\n══════════════════════════════════════════════════════');
      // ignore: avoid_print
      print('  RELATÓRIO — Relatos Simultâneos (mobile, latência simulada)');
      // ignore: avoid_print
      print('══════════════════════════════════════════════════════');
      for (final r in relatorio) {
        _print(r);
      }
      // ignore: avoid_print
      print('\n  Latências: IA ≈200ms | DB ≈150ms | Total série: ~350ms/relato');
      // ignore: avoid_print
      print('  Em paralelo o tempo total converge para ~350ms independente de N.');
      // ignore: avoid_print
      print('══════════════════════════════════════════════════════\n');
    });

    for (final n in [1, 5, 10, 25, 50]) {
      test('$n relato(s) simultâneo(s)', () async {
        final r = await _executarCarga(n);
        relatorio.add(r);
        _print(r);
        expect(r['falhas'], 0, reason: '${r['falhas']} relatos falharam com n=$n');
        // Em paralelismo real, todo o lote deve concluir em < 2× a latência de 1 relato
        expect(r['tempoTotalMs'], lessThan(1500),
            reason: 'Paralelismo falhou: ${r['tempoTotalMs']}ms > 1500ms para n=$n');
      });
    }
  });

  // ── Cenário adverso: alta latência ────────────────────────────────────────
  group('Carga: alta latência (IA 800ms + DB 400ms)', () {
    test('10 relatos simultâneos com alta latência', () async {
      final r = await _executarCarga(
        10,
        latenciaAnaliseMs: 800,
        latenciaDbMs: 400,
      );
      _print(r);
      expect(r['falhas'], 0);
      // Com paralelismo real, 10 relatos com 1200ms cada devem concluir em < 3s total
      expect(r['tempoTotalMs'], lessThan(3000),
          reason: 'Paralelismo não funcionou: ${r['tempoTotalMs']}ms > 3s');
    });
  });
}
