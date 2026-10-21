import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prever/models/alerta_notificacao.dart';
import 'package:prever/models/cidade_alertas.dart';
import 'package:prever/telas/widgets/cidade_alertas_dialog.dart';
import 'package:prever/telas/alerta_recebido_tela.dart';

void main() {
  test('Cidade identifica o mesmo destino com acentos, caixa e espaços', () {
    expect(
      topicoDaCidade(' São José dos Campos '),
      'prever_cidade_sao-jose-dos-campos',
    );
    expect(
      topicoDaCidade('SAO JOSE DOS CAMPOS'),
      topicoDaCidade('São José dos Campos'),
    );
    expect(
      topicoDaCidade('Sa\u0303o Jose\u0301 dos Campos'),
      topicoDaCidade('São José dos Campos'),
    );
    expect(topicoDaCidade('Jacareí'), isNot(topicoDaCidade('Taubaté')));
    expect(() => topicoDaCidade(''), throwsFormatException);
    expect(() => topicoDaCidade('!!!'), throwsFormatException);
  });

  test('Payload válido abre o alerta; conteúdo inválido não quebra o app', () {
    const alerta = AlertaNotificacao(
      id: '123',
      titulo: 'Alagamento',
      descricao: 'Evite a região afetada.',
      cidade: 'Jacareí',
      severidade: 'Extrema',
    );
    final parsed = AlertaNotificacao.fromPayload(alerta.toPayload())!;
    expect(parsed.id, alerta.id);
    expect(parsed.cidade, alerta.cidade);
    expect(parsed.notificationId, alerta.notificationId);
    expect(AlertaNotificacao.fromPayload('{invalid'), isNull);
    expect(AlertaNotificacao.fromData({'kind': 'outro'}), isNull);
    expect(
      AlertaNotificacao.fromData({'kind': 'alerta_web', 'alerta_id': '1'}),
      isNull,
    );
  });

  testWidgets('Usuário escolhe a cidade e pode desativar depois', (
    tester,
  ) async {
    String? cidade;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              cidade = await showDialog<String>(
                context: context,
                builder: (_) => const CidadeAlertasDialog(cidade: ''),
              );
            },
            child: const Text('Configurar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Configurar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Receber alertas'));
    await tester.pump();
    expect(find.text('Informe um nome de cidade válido.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'São José dos Campos');
    await tester.tap(find.text('Receber alertas'));
    await tester.pumpAndSettle();
    expect(cidade, 'São José dos Campos');
  });

  testWidgets('Detalhes do aviso permitem rolagem com letras grandes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: AlertaRecebidoTela(
            alerta: AlertaNotificacao(
              id: '1',
              titulo: 'Alerta de alagamento',
              descricao: 'Evite a região afetada.',
              cidade: 'São José dos Campos',
              bairro: 'Centro',
              severidade: 'Extrema',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Centro, São José dos Campos'), findsOneWidget);
    expect(find.text('Severidade: Extrema'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
