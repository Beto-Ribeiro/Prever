import 'dart:typed_data';
import 'package:branch1/telas/exportador_import.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
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
  Location location = Location();
  LatLng? localizacaoSelecionada;
  Set<Marker> markers = {};
  bool _isLoadingMap = true;
  bool _utilizarLocalizacaoAtual = true;
  ScrollPhysics _scrollPhysics = const ClampingScrollPhysics(); // NOVO

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  // Verifica permissões de localização
  Future<void> _checkLocationPermission() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        setState(() => _isLoadingMap = false);
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        setState(() => _isLoadingMap = false);
        return;
      }
    }

    _getCurrentLocation();
  }

  // Pega a localização atual do celular
  Future<void> _getCurrentLocation() async {
    try {
      LocationData _locationData = await location.getLocation();
      LatLng posicaoAtual = LatLng(
        _locationData.latitude!,
        _locationData.longitude!,
      );

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
          tipoDesastre = 'Enchente';
          break;
        case 1:
          tipoDesastre = 'Ciclone';
          break;
        case 2:
          tipoDesastre = 'Deslizamento';
          break;
        case 3:
          tipoDesastre = 'Chuva Forte';
          break;
      }

      String nivelRisco = '';
      switch (nivelSelecionado) {
        case 0:
          nivelRisco = 'Baixo';
          break;
        case 1:
          nivelRisco = 'Moderado';
          break;
        case 2:
          nivelRisco = 'Alto';
          break;
        case 3:
          nivelRisco = 'Muito Alto';
          break;
        case 4:
          nivelRisco = 'Crítico';
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
              physics: _scrollPhysics, // NOVO
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

                    GestureDetector(
                      onTap: selecionarImagem,
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(color: Colors.black54),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: imagemBytes == null
                            ? const Center(
                          child: Text(
                            'Insira uma imagem',
                            style: TextStyle(fontSize: 16),
                          ),
                        )
                            : ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.memory(
                            imagemBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
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

                    // Wrap em vez de Row: se os nomes não couberem numa
                    // linha (fonte grande), eles quebram pra linha de
                    // baixo em vez de estourar a largura da tela.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _iconDesastre(
                          0,
                          'gfx/png/icons/tipo_inundacao.png',
                          'Enchente',
                        ),
                        _iconDesastre(
                          1,
                          'gfx/png/icons/tipo_tornado.png',
                          'Ciclone',
                        ),
                        _iconDesastre(
                          2,
                          'gfx/png/icons/tipo_deslizamento.png',
                          'Deslizamento',
                        ),
                        _iconDesastre(
                          3,
                          'gfx/png/icons/tipo_tempestade.png',
                          'Chuva Forte',
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    Text(
                      'Classifique a periculosidade/risco:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    const Text(
                      '(considere 1 menor periculosidade 5 maior periculosidade)',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 15),

                    // Wrap também aqui, pelo mesmo motivo (5 itens é mais
                    // apertado ainda que os 4 de cima).
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 14,
                      runSpacing: 12,
                      children: [
                        _ensureNivelBox(0, Colors.yellow.shade700, "1"),
                        _ensureNivelBox(1, Colors.orange.shade400, "2"),
                        _ensureNivelBox(2, Colors.orange.shade700, "3"),
                        _ensureNivelBox(3, Colors.red.shade400, "4"),
                        _ensureNivelBox(4, Colors.red.shade900, "5"),
                      ],
                    ),
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

                    // Mapa: sem texto dentro, altura fixa é segura aqui.
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

                    // Sem altura fixa: o botão cresce com o texto em vez
                    // de estourar quando a letra está maior.
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: enviarRelato,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A1818),
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

  Widget _iconDesastre(int valor, String caminhoAsset, String nomeDesastre) {
    bool selecionado = tipoSelecionado == valor;
    return GestureDetector(
      onTap: () => setState(() => tipoSelecionado = valor),
      child: SizedBox(
        width: 75,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selecionado
                    ? const Color(0xFF8AB3FF)
                    : const Color(0xFF09162E),
                border: Border.all(
                  color: selecionado ? Colors.blueAccent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Image.asset(
                caminhoAsset,
                width: 32,
                height: 32,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.warning_amber_rounded,
                    color: selecionado
                        ? const Color(0xFF09162E)
                        : const Color(0xFF8AB3FF),
                    size: 32,
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

  Widget _ensureNivelBox(int valor, Color cor, String texto) {
    bool selecionado = nivelSelecionado == valor;
    return GestureDetector(
      onTap: () => setState(() => nivelSelecionado = valor),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: selecionado ? cor : Colors.transparent,
              border: Border.all(color: cor, width: 2),
            ),
            child: selecionado
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : const SizedBox(),
          ),
          const SizedBox(height: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}