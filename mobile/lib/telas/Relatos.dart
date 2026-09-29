import 'dart:typed_data';
import 'package:prever/telas/exportador_import.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';\nimport 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controles/controle_acessibilidade.dart';

class Relatos_tela extends StatefulWidget {
  final Function(int) onChangePage;
  const Relatos_tela({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<Relatos_tela> createState() => _Relatos_telaState();
}

class _Relatos_telaState extends State<Relatos_tela> {
  PlatformFile? imagemSelecionada;
  Uint8List? imagemBytes;

  int? tipoSelecionado;
  int? nivelSelecionado;

  // Variáveis para o Mapa e Localização
  GoogleMapController? mapController;
  
  LatLng? localizacaoSelecionada;
  Set<Marker> markers = {};
  bool _isLoadingMap = true;
  bool _utilizarLocalizacaoAtual = true;
  ScrollPhysics _scrollPhysics = const ClampingScrollPhysics();

  // Rótulos e cores usados no seletor de severidade (Leve / Moderada / Severa)
  final List<String> _opcoesSeveridade = const ['Leve', 'Moderada', 'Severa'];
  final List<Color> _coresSeveridade = [
    Colors.amber.shade600,
    Colors.orange.shade700,
    Colors.red.shade700,
  ];

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  // Verifica permissões de localização
  Future<void> _checkLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() => _isLoadingMap = false);
    }
  }

  // Pega a localização atual do celular
  Future<void> _getCurrentLocation() async {
    try {
      Position _locationData = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      LatLng posicaoAtual = LatLng(_locationData.latitude, _locationData.longitude);

      setState(() {
        localizacaoSelecionada = posicaoAtual;
        _isLoadingMap = false;
        _atualizarMarcador(posicaoAtual);
      });

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(posicaoAtual, 16),
        );
      }
    } catch (e) {
      print("Erro ao obter localização: $e");
      setState(() => _isLoadingMap = false);
    }
  }

  // Atualiza o marcador visual no mapa
  void _atualizarMarcador(LatLng posicao) {
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId('selecionado'),
          position: posicao,
        ),
      );
    });
  }

  // Selecionar imagem da galeria
  Future<void> selecionarImagem() async {
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (resultado != null) {
      setState(() {
        imagemSelecionada = resultado.files.single;
        imagemBytes = resultado.files.single.bytes;
      });
    }
  }

  // Texto descritivo exibido conforme o tipo de desastre selecionado
  String _descricaoTipo(int? tipo) {
    switch (tipo) {
      case 0:
        return 'Água acumulada nas ruas, casas alagadas ou rios transbordando.';
      case 1:
        return 'Ventos fortes, destruição de estruturas e risco de queda de árvores.';
      case 2:
        return 'Barrancos caindo, terra ou rochas deslizando em encostas, rachaduras grandes no solo ou muros estufados.';
      case 3:
        return 'Chuva intensa e contínua, risco de alagamentos e deslizamentos.';
      default:
        return '';
    }
  }

  // Envia os dados e coordenadas para o Supabase
  Future<void> enviarRelato() async {
    try {
      final supabase = Supabase.instance.client;
      final usuarioLogado = supabase.auth.currentUser;

      if (usuarioLogado == null) {
        _mostrarSnackBar(
          'Erro: Você precisa estar logado para enviar um relato.',
          Colors.red,
        );
        return;
      }

      if (tipoSelecionado == null ||
          nivelSelecionado == null ||
          imagemSelecionada == null ||
          imagemBytes == null ||
          localizacaoSelecionada == null) {
        _mostrarSnackBar(
          'Preencha todos os campos e selecione a localização no mapa.',
          Colors.orange,
        );
        return;
      }

      String tipoDesastre = '';
      switch (tipoSelecionado) {
        case 0:
          tipoDesastre = 'Alagamento';
          break;
        case 1:
          tipoDesastre = 'Tornado';
          break;
        case 2:
          tipoDesastre = 'Desabamento';
          break;
        case 3:
          tipoDesastre = 'Chuva Forte';
          break;
      }

      String nivelRisco = '';
      switch (nivelSelecionado) {
        case 0:
          nivelRisco = 'Leve';
          break;
        case 1:
          nivelRisco = 'Moderada';
          break;
        case 2:
          nivelRisco = 'Severa';
          break;
      }

      final String meuUserIdDoSupabase = usuarioLogado.id;

      // FORMATANDO PARA O TIPO GEOGRAPHY (PostGIS) -> POINT(longitude latitude)
      final String pontoGeografico =
          'POINT(${localizacaoSelecionada!.longitude} ${localizacaoSelecionada!.latitude})';

      final List<Map<String, dynamic>> respostaRelato = await supabase
          .from('Relato')
          .insert({
        'rel_tipo_desastre': tipoDesastre,
        'rel_descricao': nivelRisco,
        'rel_cid_id': meuUserIdDoSupabase,
        'rel_localizacao': pontoGeografico,
        'rel_data_hora': DateTime.now().toIso8601String(),
      })
          .select();

      if (respostaRelato.isEmpty) {
        throw Exception(
          "O relato foi salvo, mas não retornou os dados. Verifique o RLS.",
        );
      }

      final relatoId = respostaRelato.first['rel_id'];
      final nomeArquivo = '${DateTime.now().millisecondsSinceEpoch}.png';
      final path = 'relatos/$relatoId/$nomeArquivo';

      await supabase.storage
          .from('Fotos_Storage')
          .uploadBinary(path, imagemBytes!);

      await supabase.from('Foto').insert({
        'fto_rel_id': relatoId,
        'fto_url': path,
        'fto_cid_id': meuUserIdDoSupabase,
      });

      // Limpa todos os campos preenchidos e mostra a mensagem de sucesso
      setState(() {
        imagemSelecionada = null;
        imagemBytes = null;
        tipoSelecionado = null;
        nivelSelecionado = null;
        localizacaoSelecionada = null;
        markers.clear();
        _utilizarLocalizacaoAtual = true;
      });
      _getCurrentLocation();
      _mostrarSnackBar('Relato e foto enviados com sucesso!', Colors.green);
    } catch (e) {
      _mostrarSnackBar('Erro: $e', Colors.red);
    }
  }

  void _mostrarSnackBar(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: cor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: _scrollPhysics,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 50),
                    Text(
                      'Insira as informações para reportar:',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Seleção de imagem: caixa tracejada "Adicionar" + caixa decorativa
                    _buildImagePicker(),
                    const SizedBox(height: 25),

                    Text(
                      'Escolha o tipo de desastre:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _iconDesastre(
                          0,
                          'gfx/png/icons/tipo_inundacao.png',
                          'Alagamento',
                          Icons.water_drop_outlined,
                        ),
                        _iconDesastre(
                          1,
                          'gfx/png/icons/tipo_tornado.png',
                          'Tornado',
                          Icons.cyclone_outlined,
                        ),
                        _iconDesastre(
                          2,
                          'gfx/png/icons/tipo_deslizamento.png',
                          'Desabamento',
                          Icons.terrain_outlined,
                        ),
                        _iconDesastre(
                          3,
                          'gfx/png/icons/tipo_tempestade.png',
                          'Chuva Forte',
                          Icons.thunderstorm_outlined,
                        ),
                      ],
                    ),

                    // Caixinha com a descrição do tipo selecionado (some/aparece animando)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: tipoSelecionado == null
                          ? const SizedBox(width: double.infinity)
                          : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _descricaoTipo(tipoSelecionado),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    Text(
                      'Escolha o nível de severidade:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Seletor animado de severidade (a "pílula" desliza e muda de cor)
                    _buildSeveridadeSelector(),
                    const SizedBox(height: 25),

                    Text(
                      'Escolha o local do desastre:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Listener(
                      onPointerDown: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          setState(
                                () => _scrollPhysics =
                            const NeverScrollableScrollPhysics(),
                          );
                        }
                      },
                      onPointerUp: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          setState(
                                () => _scrollPhysics = const ClampingScrollPhysics(),
                          );
                        }
                      },
                      onPointerCancel: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          setState(
                                () => _scrollPhysics = const ClampingScrollPhysics(),
                          );
                        }
                      },
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          GestureBinding.instance.pointerSignalResolver
                              .register(event, (event) {});
                        }
                      },
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: _isLoadingMap
                              ? const Center(child: CircularProgressIndicator())
                              : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target:
                              localizacaoSelecionada ??
                                  const LatLng(-23.5505, -46.6333),
                              zoom: 15,
                            ),
                            onMapCreated: (controller) =>
                            mapController = controller,
                            markers: markers,
                            onTap: (LatLng posicao) {
                              setState(() {
                                _utilizarLocalizacaoAtual = false;
                                localizacaoSelecionada = posicao;
                                _atualizarMarcador(posicao);
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Checkbox(
                          value: _utilizarLocalizacaoAtual,
                          onChanged: (bool? valor) {
                            if (valor == true) {
                              setState(() => _utilizarLocalizacaoAtual = true);
                              _getCurrentLocation();
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Utilizar minha localização atual.',
                            style: TextStyle(
                              fontSize: 14,
                              color: acessibilidade.corPrimaria,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: enviarRelato,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC1272D),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Reportar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Caixa de seleção de imagem: a caixa da esquerda ("Adicionar") é o botão
  // que abre o seletor; a preview da foto escolhida aparece na caixa da
  // direita (em vez de substituir o botão "Adicionar").
  Widget _buildImagePicker() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: selecionarImagem,
            child: SizedBox(
              height: 92,
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: Colors.black45,
                  radius: 12,
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 26,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Adicionar',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: selecionarImagem, // também permite trocar a foto por aqui
            child: Container(
              height: 92,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: imagemBytes == null
                  ? null
                  : ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  imagemBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Seletor de severidade em formato de pílula com 3 opções. O preenchimento
  // colorido desliza (AnimatedPositioned) e troca de cor (AnimatedContainer)
  // conforme a opção escolhida.
  Widget _buildSeveridadeSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double largura = constraints.maxWidth;
        final double larguraItem = largura / _opcoesSeveridade.length;
        final int indiceAtivo = nivelSelecionado ?? 0;

        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              if (nivelSelecionado != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: larguraItem * indiceAtivo,
                  top: 0,
                  bottom: 0,
                  width: larguraItem,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _coresSeveridade[indiceAtivo],
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              Row(
                children: List.generate(_opcoesSeveridade.length, (index) {
                  final bool selecionado = nivelSelecionado == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => nivelSelecionado = index),
                      child: SizedBox(
                        height: 46,
                        child: Center(
                          child: Text(
                            _opcoesSeveridade[index],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: selecionado
                                  ? Colors.white
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconDesastre(
      int valor,
      String caminhoAsset,
      String nomeDesastre,
      IconData iconeFallback,
      ) {
    bool selecionado = tipoSelecionado == valor;
    return GestureDetector(
      onTap: () => setState(() => tipoSelecionado = valor),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selecionado ? Colors.blue.shade50 : Colors.white,
                border: Border.all(
                  color: selecionado ? Colors.blue.shade700 : Colors.grey.shade300,
                  width: selecionado ? 2.6 : 1.4,
                ),
              ),
              child: Image.asset(
                caminhoAsset,
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    iconeFallback,
                    color: Colors.blue.shade300,
                    size: 38,
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Text(
              nomeDesastre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                color: selecionado ? Colors.blue.shade900 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Desenha uma borda tracejada arredondada (usada na caixa "Adicionar" imagem).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  _DashedBorderPainter({
    this.color = Colors.black45,
    this.strokeWidth = 1.4,
    this.radius = 12,
    this.dashWidth = 6,
    this.dashSpace = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double proximo = distance + dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, proximo.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = proximo + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}