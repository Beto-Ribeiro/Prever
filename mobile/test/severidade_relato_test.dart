import 'package:prever/services/severidade_relato.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Reconhece os três níveis salvos pela tela de relatos', () {
    expect(identificarSeveridade('Leve'), SeveridadeRelato.leve);
    expect(identificarSeveridade('Moderada'), SeveridadeRelato.moderada);
    expect(identificarSeveridade('Severa'), SeveridadeRelato.severa);
  });

  test('Reconhece extrema, crítica e variações de relatos anteriores', () {
    for (final texto in [
      'Extrema',
      'Extremo',
      'Crítico',
      'Crítica',
      'Critico',
      'Severo',
      ' SEVERA ',
      'Severidade: EXTREMA',
    ]) {
      expect(
        identificarSeveridade(texto),
        SeveridadeRelato.severa,
        reason: texto,
      );
    }
    expect(identificarSeveridade('Moderado'), SeveridadeRelato.moderada);
    expect(identificarSeveridade(' leve '), SeveridadeRelato.leve);
  });

  test(
    'Não confunde severidade ausente ou desconhecida com um nível válido',
    () {
      for (final texto in [null, '', 'Sem informação', 'levemente']) {
        expect(identificarSeveridade(texto), SeveridadeRelato.desconhecida);
      }
    },
  );
}
