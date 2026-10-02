import 'dart:async';
import 'package:prever/controles/controle_acessibilidade.dart';
import 'package:prever/services/relatos_proximos_service.dart';
import 'package:prever/telas/widgets/relatos_proximos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test(
    'Filtra por raio, ignora coordenadas inválidas e SOS, ordena por distância',
    () {
      Map<String, dynamic> relato(dynamic lat, dynamic lon, String tipo) => {
        'latitude': lat,
        'longitude': lon,
        'rel_tipo_desastre': tipo,
        'rel_descricao': 'Moderado',
      };
      final resultado = filtrarRelatosProximos(
        [
          relato(0.05, 0, 'Chuva Forte'),
          relato(0, 0, 'SOS'),
          relato(0.2, 0, 'Tornado'),
          relato(null, 0, 'Alagamento'),
          relato('NaN', 0, 'Alagamento'),
          relato(91, 0, 'Alagamento'),
          relato('0.01', '0', 'Desabamento'),
          relato(0, 0, 'Alagamento'),
        ],
        0,
        0,
        raioMetros: 10000,
      );
      expect(resultado.map((r) => r.tipo), [
        'Alagamento',
        'Desabamento',
        'Chuva Forte',
      ]);
      expect(resultado.last.distanciaMetros, inInclusiveRange(5500, 5600));
      expect(
        filtrarRelatosProximos(
          [relato(0, 0, 'Chuva Forte')],
          0,
          0,
          raioMetros: 0,
        ),
        hasLength(1),
      );
    },
  );

  Widget tela(
    Future<List<RelatoProximo>> Function() carregar, {
    bool ativa = true,
  }) {
    return ChangeNotifierProvider(
      create: (_) => AccessibilityController(),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: RelatosProximos(ativa: ativa, carregar: carregar),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'Carrega ao abrir e voltar para home; atualizar busca novos relatos',
    (tester) async {
      var chamadas = 0;
      Future<List<RelatoProximo>> carregar() async {
        chamadas++;
        return [const RelatoProximo('Alagamento', 'Moderado', 1500)];
      }

      await tester.pumpWidget(tela(carregar, ativa: false));
      expect(chamadas, 0);
      await tester.pumpWidget(tela(carregar));
      await tester.pumpAndSettle();
      expect(chamadas, 1);
      expect(find.text('1,5 km de você'), findsOneWidget);
      expect(find.text('Moderado'), findsOneWidget);
      await tester.tap(find.byTooltip('Atualizar relatos'));
      await tester.pumpAndSettle();
      expect(chamadas, 2);
      await tester.pumpWidget(tela(carregar, ativa: false));
      await tester.pumpWidget(tela(carregar));
      await tester.pumpAndSettle();
      expect(chamadas, 3);
    },
  );

  testWidgets(
    'Exibe carregamento, erro de localização e permite tentar novamente',
    (tester) async {
      final pendente = Completer<List<RelatoProximo>>();
      var chamadas = 0;
      await tester.pumpWidget(
        tela(() {
          chamadas++;
          return chamadas == 1 ? pendente.future : Future.value([]);
        }),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pendente.completeError(
        const LocalizacaoIndisponivel('Ative a localização.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ative a localização.'), findsOneWidget);
      await tester.tap(find.byTooltip('Atualizar relatos'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhum relato encontrado a até 3 km de você.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('Conclusão após sair da tela não atualiza estado descartado', (
    tester,
  ) async {
    final pendente = Completer<List<RelatoProximo>>();
    await tester.pumpWidget(tela(() => pendente.future));
    await tester.pumpWidget(const SizedBox());
    pendente.complete([]);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('Preserva identificação e coordenadas para abrir o relato correto', () {
    final relato = filtrarRelatosProximos(
      [
        {
          'rel_id': 42,
          'latitude': '-23.01',
          'longitude': '-45.53',
          'rel_tipo_desastre': 'Alagamento',
        },
      ],
      -23.01,
      -45.53,
    ).single;
    expect(relato.id, '42');
    expect(relato.latitude, -23.01);
    expect(relato.longitude, -45.53);
  });

  testWidgets(
    'Botão envia o relato escolhido mesmo sem foto, em tela estreita',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const primeiro = RelatoProximo(
        'Alagamento',
        'Moderado',
        100,
        id: '1',
        latitude: -23,
        longitude: -45,
      );
      const segundo = RelatoProximo(
        'Chuva Forte',
        'Crítico',
        300,
        id: '2',
        latitude: -23.001,
        longitude: -45,
      );
      RelatoProximo? selecionado;
      final fotosSolicitadas = <String>[];
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AccessibilityController()..toggleAltoContraste(),
          child: MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: SingleChildScrollView(
                  child: RelatosProximos(
                    ativa: true,
                    carregar: () async => [primeiro, segundo],
                    carregarFoto: (id) async {
                      fotosSolicitadas.add(id);
                      if (id == '2') throw Exception('Foto indisponível');
                      return null;
                    },
                    onAbrirRelato: (relato) => selecionado = relato,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fotosSolicitadas, ['1', '2']);
      expect(find.byTooltip('Foto indisponível'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Ver no mapa').last);
      await tester.tap(find.text('Ver no mapa').last);
      expect(selecionado, same(segundo));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Miniatura usa a URL da ocorrência e trata falha ao baixar imagem',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AccessibilityController(),
          child: MaterialApp(
            home: FotoRelato(
              relato: const RelatoProximo('Alagamento', 'Leve', 10, id: '42'),
              icone: Icons.water,
              carregar: (id) async =>
                  'https://example.com/relatos/$id/foto.png',
            ),
          ),
        ),
      );
      await tester.pump();
      final imagem = tester.widget<Image>(find.byType(Image));
      expect(
        (imagem.image as NetworkImage).url,
        'https://example.com/relatos/42/foto.png',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
