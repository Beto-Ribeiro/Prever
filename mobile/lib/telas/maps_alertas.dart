import 'package:prever/services/severidade_relato.dart';
import 'dart:async';
import 'package:prever/services/relatos_proximos_service.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exportador_import.dart';

class Maps_alertas extends StatefulWidget {
  final Function(int) onChangePage;
  final String title;
  final RelatoProximo? relatoSelecionado;
  final int solicitacaoRelato;

  const Maps_alertas({
    super.key,
    required this.title,
    required this.onChangePage,
    this.relatoSelecionado,
    this.solicitacaoRelato = 0,
  });

  @override
  State<Maps_alertas> createState() => _MapsAlertas();
}

class _MapsAlertas extends State<Maps_alertas> {
  late final Future<void> _iconesProntos;

  @override
  void didUpdateWidget(covariant Maps_alertas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.solicitacaoRelato != oldWidget.solicitacaoRelato) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focarRelato());
    }
  }

  Future<void> _focarRelato() async {
    final relato = widget.relatoSelecionado;
    final solicitacao = widget.solicitacaoRelato;
    if (relato?.id == null ||
        relato?.latitude == null ||
        relato?.longitude == null) {
      return;
    }
    try {
      final controller = await _controller.future;
      if (!mounted || solicitacao != widget.solicitacaoRelato) return;
      FunctionAbrirmarker(relato!.id!);
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(relato.latitude!, relato.longitude!),
          16,
        ),
      );
      await carregarPins();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível centralizar o relato no mapa. Tente novamente.',
            ),
          ),
        );
      }
    }
  }

  BitmapDescriptor? chuvaForteBluIcon;
  BitmapDescriptor? chuvaForteOraIcon;
  BitmapDescriptor? chuvaForteRedIcon;
  BitmapDescriptor? chuvaForteYelIcon;

  BitmapDescriptor? deslizamentoBluIcon;
  BitmapDescriptor? deslizamentoOraIcon;
  BitmapDescriptor? deslizamentoRedIcon;
  BitmapDescriptor? deslizamentoYelIcon;

  BitmapDescriptor? inundacaoBluIcon;
  BitmapDescriptor? inundacaoOraIcon;
  BitmapDescriptor? inundacaoRedIcon;
  BitmapDescriptor? inundacaoYelIcon;

  BitmapDescriptor? tornadoBluIcon;
  BitmapDescriptor? tornadoOraIcon;
  BitmapDescriptor? tornadoRedIcon;
  BitmapDescriptor? tornadoYelIcon;

  BitmapDescriptor? appleIcon;
  BitmapDescriptor? googleLogoIcon;

  BitmapDescriptor? tipoDeslizamentoIcon;
  BitmapDescriptor? tipoInundacaoIcon;
  BitmapDescriptor? tipoTempestadeIcon;
  BitmapDescriptor? tipoTornadoIcon;

  bool abriuMarker = false;
  String _selectedMarkerId = '';

  void FunctionAbrirmarker(String ID) {
    setState(() {
      abriuMarker = true;
      _selectedMarkerId = ID;
    });
  }

  void FunctionFecharmarker() {
    setState(() {
      abriuMarker = false;
    });
  }

  MapType _mapType = MapType.normal;
  bool _is3D = false;
  CameraPosition? _currentCameraPosition;

  void _mostrarOpcoesMapa() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tipo de Mapa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.map, color: Colors.white),
                title: Text('Ruas (2D)', style: TextStyle(color: Colors.white)),
                trailing: _mapType == MapType.normal && !_is3D
                    ? Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _mapType = MapType.normal;
                    _is3D = false;
                  });
                  _atualizarCameraTilt(0.0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.satellite, color: Colors.white),
                title: Text('Satélite', style: TextStyle(color: Colors.white)),
                trailing: _mapType == MapType.satellite
                    ? Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _mapType = MapType.satellite;
                    _is3D = false;
                  });
                  _atualizarCameraTilt(0.0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.terrain, color: Colors.white),
                title: Text('Relevo', style: TextStyle(color: Colors.white)),
                trailing: _mapType == MapType.terrain
                    ? Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    _mapType = MapType.terrain;
                    _is3D = false;
                  });
                  _atualizarCameraTilt(0.0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.threed_rotation, color: Colors.white),
                title: Text('Visão 3D', style: TextStyle(color: Colors.white)),
                trailing: _is3D ? Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    _mapType = MapType.normal;
                    _is3D = true;
                  });
                  _atualizarCameraTilt(45.0);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _atualizarCameraTilt(double tilt) async {
    final controller = await _controller.future;

    // Se a câmera nunca foi movida, criamos uma posição baseada no Target Inicial ou na Localização
    CameraPosition targetPosition =
        _currentCameraPosition ??
        CameraPosition(
          target: position != null
              ? LatLng(position!.latitude, position!.longitude)
              // IMPORTANTE (TESTE 3D): Cidades do interior (como Taubaté abaixo) muitas vezes não têm edifícios 3D mapeados pelo Google.
              // Se o mapa ficar plano no emulador, teste trocar para São Paulo: const LatLng(-23.550520, -46.633308)
              : const LatLng(-23.014336, -45.538053),
          zoom: 15,
        );

    double newZoom = targetPosition.zoom;
    // O 3D (buildings) só costuma aparecer em níveis de zoom maiores (ex: 17 ou 18+)
    if (tilt > 0 && newZoom < 17.5) {
      newZoom = 17.5;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetPosition.target,
          zoom: newZoom,
          bearing: targetPosition.bearing,
          tilt: tilt,
        ),
      ),
    );

    // Recarrega os pins após a animação para garantir que os marcadores permanecem visíveis
    await carregarPins();
  }

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  final supabase = Supabase.instance.client;

  // corFundoMenu moved to build

  Set<Marker> markers = {};

  bool boolStatus = false;
  Position? position;

  Future<void> carregarIcones() async {
    chuvaForteBluIcon = await criarIconeMarker('chuva forte - blu.png');

    chuvaForteOraIcon = await criarIconeMarker('chuva forte - ora.png');

    chuvaForteRedIcon = await criarIconeMarker('chuva forte - red.png');

    chuvaForteYelIcon = await criarIconeMarker('chuva forte - yel.png');

    deslizamentoBluIcon = await criarIconeMarker('deslizamento - blu.png');

    deslizamentoOraIcon = await criarIconeMarker('deslizamento - ora.png');

    deslizamentoRedIcon = await criarIconeMarker('deslizamento - red.png');

    deslizamentoYelIcon = await criarIconeMarker('deslizamento - yel.png');

    inundacaoBluIcon = await criarIconeMarker('inundação - blu.png');

    inundacaoOraIcon = await criarIconeMarker('inundação - ora.png');

    inundacaoRedIcon = await criarIconeMarker('inundação - red.png');

    inundacaoYelIcon = await criarIconeMarker('inundação - yel.png');

    tornadoBluIcon = await criarIconeMarker('tornado - blu.png');

    tornadoOraIcon = await criarIconeMarker('tornado - ora.png');

    tornadoRedIcon = await criarIconeMarker('tornado - red.png');

    tornadoYelIcon = await criarIconeMarker('tornado - yel.png');

    appleIcon = await criarIconeMarker('apple.png');

    googleLogoIcon = await criarIconeMarker('google_logo.png');

    tipoDeslizamentoIcon = await criarIconeMarker('tipo_deslizamento.png');

    tipoInundacaoIcon = await criarIconeMarker('tipo_inundacao.png');

    tipoTempestadeIcon = await criarIconeMarker('tipo_tempestade.png');

    tipoTornadoIcon = await criarIconeMarker('tipo_tornado.png');
  }

  Future<void> inicializarMapa() async {
    try {
      await _iconesProntos;
      if (!mounted) return;
      await carregarPins();
      if (widget.relatoSelecionado == null) {
        await _GoToUserLocation(inicial: true);
      }
    } catch (e) {
      debugPrint('Erro ao inicializar mapa: $e');
    }
  }

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _iconesProntos = carregarIcones();
    inicializarMapa();
    if (widget.relatoSelecionado != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focarRelato());
    }

    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (timer) {
        carregarPins().catchError((Object e) {
          debugPrint('Erro ao atualizar relatos do mapa: $e');
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _GoToUserLocation({bool inicial = false}) async {
    PermissionStatus status = await Permission.location.request();

    if (!status.isGranted) {
      return;
    }

    position = await Geolocator.getCurrentPosition();
    if (!mounted) return;

    setState(() {
      boolStatus = true;
    });

    GoogleMapController controller = await _controller.future;
    if (!mounted || (inicial && widget.relatoSelecionado != null)) return;

    controller.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(
          position!.latitude,
          position!.longitude,
        ),
        15,
      ),
    );

    await carregarPins();
  }

  Future<BitmapDescriptor> criarIconeMarker(String arquivo) async {
    ByteData data = await rootBundle.load(
      'gfx/png/icons/$arquivo',
    );

    Uint8List bytes = data.buffer.asUint8List();

    return BitmapDescriptor.bytes(bytes, width: 100);
  }

  BitmapDescriptor _iconeRelato(String? tipo, String? descricao) {
    final (amarelo, laranja, vermelho, azul) = switch (tipo) {
      'Alagamento' => (
        inundacaoYelIcon,
        inundacaoOraIcon,
        inundacaoRedIcon,
        inundacaoBluIcon,
      ),
      'Desabamento' => (
        deslizamentoYelIcon,
        deslizamentoOraIcon,
        deslizamentoRedIcon,
        deslizamentoBluIcon,
      ),
      'Tornado' => (
        tornadoYelIcon,
        tornadoOraIcon,
        tornadoRedIcon,
        tornadoBluIcon,
      ),
      _ => (
        chuvaForteYelIcon,
        chuvaForteOraIcon,
        chuvaForteRedIcon,
        chuvaForteBluIcon,
      ),
    };
    return switch (identificarSeveridade(descricao)) {
      SeveridadeRelato.leve => amarelo!,
      SeveridadeRelato.moderada => laranja!,
      SeveridadeRelato.severa => vermelho!,
      SeveridadeRelato.desconhecida => azul!,
    };
  }

  Future<void> carregarPins() async {
    await _iconesProntos;
    if (!mounted) return;

    final response = await supabase.from('relatos_mapa').select();

    Set<Marker> novosMarkers = {};

    for (final item in response) {
      if (item['latitude'] == null || item['longitude'] == null) {
        continue;
      }
      if (item['rel_tipo_desastre'] == 'SOS') {
        continue;
      }

      novosMarkers.add(
        Marker(
          markerId: MarkerId(
            item['rel_id'].toString(),
          ),

          onTap: () {
            FunctionAbrirmarker(item['rel_id'].toString());
          },

          position: LatLng(
            item['latitude'],
            item['longitude'],
          ),

          anchor: const Offset(0.5, 0.5),

          icon: _iconeRelato(
            item['rel_tipo_desastre']?.toString(),
            item['rel_descricao']?.toString(),
          ),

          infoWindow: InfoWindow(
            title: item['rel_tipo_desastre'].toString(),
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      markers = novosMarkers;
    });
  }

  final estiloMapa = '''
    [
      {
        "featureType": "poi.business",
        "elementType": "all",
        "stylers": [
          {
            "visibility": "off"
          }
        ]
      },
      {
      "featureType": "poi.school",
      "elementType": "all",
      "stylers": [
        {
          "visibility": "off"
        }
      ]
    },
    {
    "featureType": "poi.school",
    "elementType": "all",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  }
    ]
    ''';

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          mapType: _mapType,
          // Edifícios 3D só aparecem quando _is3D está ativo;
          // manter true no modo 2D pode aumentar o uso de GPU sem benefício visual.
          buildingsEnabled: _is3D,
          onCameraMove: (position) {
            _currentCameraPosition = position;
          },
          onMapCreated: (GoogleMapController controller) {
            if (!_controller.isCompleted) _controller.complete(controller);
          },
          // Estilos personalizados SUPRIMEM a renderização de edifícios 3D.
          // No modo 3D limpamos o estilo para que os prédios apareçam corretamente.
          style: _is3D ? null : estiloMapa,

          markers: markers,

          myLocationEnabled: true,

          myLocationButtonEnabled: false,

          zoomControlsEnabled: false,

          compassEnabled: false,

          mapToolbarEnabled: false,

          initialCameraPosition: CameraPosition(
            target: boolStatus && position != null
                ? LatLng(
                    position!.latitude,
                    position!.longitude,
                  )
                // IMPORTANTE (TESTE 3D): Troque para -23.550520, -46.633308 (São Paulo) se for emular e o 3D não aparecer em Taubaté.
                : const LatLng(
                    -23.014336,
                    -45.538053,
                  ),

            zoom: 15,
          ),
        ),

        Positioned(
          bottom: 220,
          right: 16,
          child: FloatingActionButton(
            heroTag: "btnConfigMapa",
            backgroundColor: Theme.of(context).colorScheme.primary,
            elevation: 4,
            shape: const CircleBorder(),
            onPressed: _mostrarOpcoesMapa,
            child: Icon(
              Icons.layers,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: 150,

          right: 16,

          child: FloatingActionButton(
            heroTag: "btnLocalizacaoMapaUnico",

            backgroundColor: Theme.of(context).colorScheme.primary,

            elevation: 4,

            shape: const CircleBorder(),

            onPressed: () => _GoToUserLocation(),

            child: Icon(
              Icons.my_location,
              color: Colors.white,
            ),
          ),
        ),
        abriuMarker
            ? PinsVisao(
                pinID: _selectedMarkerId,
                FecharPinVisao: FunctionFecharmarker,
              )
            : Container(),
      ],
    );
  }
}
