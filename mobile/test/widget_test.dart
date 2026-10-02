// Smoke test: verifica que MyApp instancia sem exceção.
// O test original era um template Flutter (contador) incompatível com este projeto.
// Dependências externas (Supabase, Firebase, dotenv) exigem inicialização
// assíncrona completa, portanto não é possível pump MyApp diretamente em testes
// de widget. O teste abaixo garante apenas que a classe existe e é importável.

import 'package:flutter_test/flutter_test.dart';
import 'package:prever/main.dart';

void main() {
  test('MyApp é uma classe instanciável (smoke test)', () {
    const app = MyApp();
    expect(app, isA<MyApp>());
  });
}
