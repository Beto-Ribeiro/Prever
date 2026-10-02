import 'dart:async';
import 'dart:convert';
import 'package:prever/telas/login_tela.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MemoriaAuth extends GotrueAsyncStorage {
  const _MemoriaAuth();
  @override
  Future<String?> getItem({required String key}) async => null;
  @override
  Future<void> setItem({required String key, required String value}) async {}
  @override
  Future<void> removeItem({required String key}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Future<http.Response> Function(http.Request) responder;

  setUpAll(() async {
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-key',
      debug: false,
      httpClient: MockClient((request) => responder(request)),
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
        pkceAsyncStorage: _MemoriaAuth(),
      ),
    );
  });
  tearDownAll(() => Supabase.instance.dispose());

  testWidgets('Login, logout e novo login não deixam o botão bloqueado', (
    tester,
  ) async {
    var chamadas = 0;
    final pendente = Completer<http.Response>();
    responder = (request) async {
      if (request.url.path.endsWith('/logout')) return http.Response('', 204);
      chamadas++;
      if (chamadas == 1) return pendente.future;
      return http.Response('{"msg":"Credenciais inválidas"}', 400);
    };
    var pagina = 7;
    late StateSetter navegar;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            navegar = setState;
            return IndexedStack(
              index: pagina == 7 ? 0 : 1,
              children: [
                SLogin(
                  title: 'Login',
                  onChangePage: (index) => setState(() => pagina = index),
                ),
                const Text('Home'),
              ],
            );
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'teste@example.com');
    await tester.enterText(find.byType(TextField).last, 'senha-teste');
    await tester.ensureVisible(find.text('Acessar'));
    await tester.tap(find.text('Acessar'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pendente.complete(
      http.Response(
        jsonEncode({
          'access_token': 'test-token',
          'refresh_token': 'refresh-token',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': 'usuario-teste',
            'aud': 'authenticated',
            'email': 'teste@example.com',
            'created_at': '2026-01-01T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(pagina, 0);
    await Supabase.instance.client.auth.signOut();
    navegar(() => pagina = 7);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final botao = find.widgetWithText(ElevatedButton, 'Acessar');
    expect(tester.widget<ElevatedButton>(botao).onPressed, isNotNull);
    await tester.enterText(find.byType(TextField).last, 'senha-incorreta');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
    expect(chamadas, 2);
    expect(tester.widget<ElevatedButton>(botao).onPressed, isNotNull);
    expect(find.text('E-mail ou senha inválidos.'), findsOneWidget);
  });

  testWidgets(
    'Links cabem em tela pequena com letras grandes e teclado aberto',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? pagina;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              viewInsets: EdgeInsets.only(bottom: 250),
            ),
            child: SLogin(
              title: 'Login',
              onChangePage: (index) => pagina = index,
            ),
          ),
        ),
      );
      final cadastro = find.text('Não tenho uma conta prever');
      await tester.ensureVisible(cadastro);
      await tester.pumpAndSettle();
      final limites = tester.getRect(cadastro);
      expect(limites.left, greaterThanOrEqualTo(0));
      expect(limites.right, lessThanOrEqualTo(320));
      await tester.tap(cadastro);
      expect(pagina, 5); // onChangePage(5) → cadastro
      await tester.ensureVisible(find.text('Esqueci a senha'));
      await tester.tap(find.text('Esqueci a senha'));
      expect(pagina, 11); // onChangePage(11) → esqueci senha
      expect(tester.takeException(), isNull);
    },
  );
}
