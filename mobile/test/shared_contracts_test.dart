import 'package:flutter_test/flutter_test.dart';
import 'package:prever/shared/prever_contracts.dart';

void main() {
  group('Contratos compartilhados gerados (/shared -> Dart)', () {
    test('Constantes de tabelas, buckets, Edge Functions e Antifraude', () {
      expect(PreverTables.perfis, 'perfis');
      expect(PreverTables.relatos, 'relatos');
      expect(PreverStorageBuckets.fotosRelatos, 'fotos_relatos');
      expect(PreverEdgeFunctions.smdnAi, 'smdn-ai');
      expect(PreverAntifraudConfig.minLegitimateScore, 0.8);
      expect(PreverAntifraudConfig.fallbackStatus, 'pendente_revisao');
    });

    test(
      'Serialização e desserialização de OcorrenciaRelatoDto e AbrigoEmergenciaDto',
      () {
        final relato = OcorrenciaRelatoDto.fromJson({
          'rel_id': 99,
          'prf_id': 'user-1',
          'rel_tipo': 'Deslizamento',
          'rel_gravidade': 'Crítico',
          'rel_latitude': -23.02,
          'rel_longitude': -45.55,
          'rel_data_hora': '2026-10-29T12:00:00Z',
          'rel_score_antifraude': 0.91,
          'rel_status_validacao': 'legitimo',
        });

        expect(relato.relId, '99');
        expect(relato.relGravidade, 'Crítico');
        expect(relato.relScoreAntifraude, 0.91);
        expect(relato.toJson()['rel_tipo'], 'Deslizamento');

        final abrigo = AbrigoEmergenciaDto.fromJson({
          'abr_id': 'abr-10',
          'abr_nome': 'Escola Central',
          'abr_cidade': 'Taubaté',
          'abr_endereco': 'Av. Principal, 100',
          'abr_latitude': -23.02,
          'abr_longitude': -45.55,
          'abr_capacidade': 200,
          'abr_ocupacao': 80,
        });

        expect(abrigo.abrCapacidade, 200);
        expect(abrigo.abrStatus, 'disponivel');
        expect(abrigo.toJson()['abr_cidade'], 'Taubaté');
      },
    );
  });
}
