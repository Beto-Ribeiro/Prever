import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:prever/services/alerta_geografico.dart';

void main() {
  double latitudeParaMetros(double metros) =>
      metros / raioTerraMetros * 180 / math.pi;

  test('inclui distâncias menores ou iguais a 20 km e exclui as maiores', () {
    expect(estaNoRaioDoAlerta(0, 0, 0, 0), isTrue);
    expect(estaNoRaioDoAlerta(0, 0, latitudeParaMetros(19999), 0), isTrue);
    expect(estaNoRaioDoAlerta(0, 0, latitudeParaMetros(20000), 0), isTrue);
    expect(estaNoRaioDoAlerta(0, 0, latitudeParaMetros(20001), 0), isFalse);
  });

  test('mede arco conhecido e não confunde graus com quilômetros', () {
    expect(distanciaEntreCoordenadas(0, 0, 1, 0), closeTo(111195.08, 0.1));
    expect(estaNoRaioDoAlerta(-23.5505, -46.6333, -22.9068, -43.1729), isFalse);
    expect(estaNoRaioDoAlerta(0, 179.99, 0, -179.99), isTrue);
  });

  test(
    'rejeita coordenadas não finitas ou fora dos limites de ambos os lados',
    () {
      for (final invalida in [
        double.nan,
        double.infinity,
        -double.infinity,
        91.0,
      ]) {
        expect(estaNoRaioDoAlerta(invalida, 0, 0, 0), isFalse);
        expect(estaNoRaioDoAlerta(0, 0, invalida, 0), isFalse);
      }
      expect(estaNoRaioDoAlerta(0, 181, 0, 0), isFalse);
      expect(estaNoRaioDoAlerta(0, 0, 0, -181), isFalse);
    },
  );

  test(
    'aceita payload FCM com coordenadas string e rejeita payload incompleto',
    () {
      final dados = <String, dynamic>{
        'tipo': 'alerta_web',
        'alerta_id': 'id-alerta',
        'latitude': '-23.55',
        'longitude': '-46.63',
        'titulo': 'Chuva intensa',
        'descricao': 'Evite áreas alagadas.',
      };
      final alerta = AlertaGeografico.deMensagem(dados)!;
      expect(alerta.latitude, -23.55);
      expect(alerta.longitude, -46.63);
      expect(alerta.id, 'id-alerta');
      for (final campo in ['tipo', 'alerta_id', 'latitude', 'longitude']) {
        expect(AlertaGeografico.deMensagem({...dados}..remove(campo)), isNull);
      }
      for (final invalida in ['', 'NaN', 'Infinity', '91', null]) {
        expect(
          AlertaGeografico.deMensagem({...dados, 'latitude': invalida}),
          isNull,
        );
      }
      expect(
        AlertaGeografico.deMensagem({...dados, 'longitude': '181'}),
        isNull,
      );
      expect(AlertaGeografico.deMensagem({...dados, 'alerta_id': ' '}), isNull);
    },
  );
}
