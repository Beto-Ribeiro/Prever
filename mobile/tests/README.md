# Suíte de Testes Mobile (`mobile/test`)

Por convenção do executor `flutter test`, os arquivos executáveis de teste do pacote Flutter residem em [`../test/`](../test/), incluindo:

- [`../test/carga_relatos_test.dart`](../test/carga_relatos_test.dart): Testes unitários de regra de negócio e testes de carga/concorrência (1 a 50 relatos simultâneos) do motor antifraude e persistência.
- [`../test/login_tela_test.dart`](../test/login_tela_test.dart): Testes de widget para o ciclo completo de login, logout, responsividade e acessibilidade com fonte ampliada.
- [`../test/relatos_proximos_test.dart`](../test/relatos_proximos_test.dart): Testes de widget para listagem de relatos próximos, tratamento de erro de GPS e fallback de miniaturas.
- [`../test/prever_logo_test.dart`](../test/prever_logo_test.dart): Testes de renderização do logotipo vetorial PREVER.
- [`../test/widget_test.dart`](../test/widget_test.dart): Smoke test de instanciação da aplicação (`MyApp`).
