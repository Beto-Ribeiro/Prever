import 'package:prever/services/severidade_relato.dart';
import 'dart:async';
import 'package:prever/services/relatos_proximos_service.dart';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exportador_import.dart';

class Maps_alertas extends StatefulWidget {
  final Function(int) onChangePage;
  final String title;
  final RelatoProximo? relatoSelecionado;
  final int solicitacaoRelato;

  Maps_alertas({
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

  FunctionAbrirmarker(String ID) {
    setState(() {
      abriuMarker = true;
      _selectedMarkerId = ID;
    });
  }

  FunctionFecharmarker() {
    setState(() {
      abriuMarker = false;
    });
  }

  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  final supabase = Supabase.instance.client;

  final Color corFundoMenu = const Color(0xFF0B1426);

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
          onMapCreated: (GoogleMapController controller) {
            if (!_controller.isCompleted) _controller.complete(controller);
          },
          style: estiloMapa,

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
                : const LatLng(
                    -23.014336,
                    -45.538053,
                  ),

            zoom: 15,
          ),
        ),

        Positioned(
          bottom: 150,

          right: 16,

          child: FloatingActionButton(
            heroTag: "btnLocalizacaoMapaUnico",

            backgroundColor: corFundoMenu,

            elevation: 4,

            shape: const CircleBorder(),

            onPressed: () => _GoToUserLocation(),

            child: const Icon(
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
