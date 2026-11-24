import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prever/telas/confEmail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  testWidgets(
    'ConfEmail valida confirmação, navega para Home e trata e-mail ainda pendente',
    (tester) async {
      int? paginaDestino;
      var tentativa = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ConfEmail(
            title: 'Confirmação',
            email: 'cidadao@prever.app',
            senha: 'senhaSegura123',
            onChangePage: (index) => paginaDestino = index,
            onVerificarSessao: (email, senha) async {
              tentativa++;
              if (tentativa == 1) {
                throw const AuthException('Email not confirmed');
              }
              expect(email, 'cidadao@prever.app');
              expect(senha, 'senhaSegura123');
              return true;
            },
          ),
        ),
      );

      expect(
        find.text('Enviamos um link para cidadao@prever.app'),
        findsOneWidget,
      );

      final botaoConfirmar = find.byKey(const Key('botao_ja_confirmei'));
      await tester.tap(botaoConfirmar);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'E-mail ainda não confirmado. Verifique sua caixa de entrada e spam.',
        ),
        findsOneWidget,
      );
      expect(paginaDestino, isNull);

      ScaffoldMessenger.of(
        tester.element(find.byType(ConfEmail)),
      ).clearSnackBars();
      await tester.pumpAndSettle();

      await tester.tap(botaoConfirmar);
      await tester.pumpAndSettle();

      expect(paginaDestino, 0);
    },
  );

  testWidgets(
    'ConfEmail permite reenviar link com deep link mobile e aplica cooldown de 60s',
    (tester) async {
      final envios = <Map<String, String>>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ConfEmail(
            title: 'Confirmação',
            email: 'maria@prever.app',
            senha: 'senhaSegura123',
            onChangePage: (_) {},
            onReenviarEmail: (email, redirectTo) async {
              envios.add({'email': email, 'redirectTo': redirectTo});
            },
          ),
        ),
      );

      final botaoReenviar = find.byKey(const Key('botao_reenviar_confirmacao'));
      await tester.tap(botaoReenviar);
      await tester.pump();

      expect(envios, [
        {
          'email': 'maria@prever.app',
          'redirectTo': 'com.prever.app://login-callback',
        },
      ]);
      expect(
        find.text(
          'Novo e-mail de confirmação enviado! Verifique sua caixa de entrada e spam.',
        ),
        findsOneWidget,
      );

      // Enquanto estiver em cooldown, o botão permanece desabilitado.
      expect(tester.widget<TextButton>(botaoReenviar).onPressed, isNull);
      expect(find.textContaining('Reenviar e-mail ('), findsOneWidget);

      await tester.pump(const Duration(seconds: 61));
      expect(tester.widget<TextButton>(botaoReenviar).onPressed, isNotNull);
    },
  );
}
