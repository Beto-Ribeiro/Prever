import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'exportador_import.dart';

class Maps_alertas extends StatefulWidget {
  final Function(int) onChangePage;
  final String title;

  Maps_alertas({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  @override
  State<Maps_alertas> createState() => _MapsAlertas();
}

class _MapsAlertas extends State<Maps_alertas> {
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
  String SelectedMarkerId = '';

  FunctionAbrirmarker(String ID) {
    setState(() {
      abriuMarker = true;
      SelectedMarkerId = ID;
    });
  }

  FunctionFecharmarker(){
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
    await carregarIcones();
    await _GoToUserLocation();
  }

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    inicializarMapa();

    _timer = Timer.periodic(
      const Duration(seconds: 10),
          (timer) {
        carregarPins();
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _GoToUserLocation() async {
    PermissionStatus status = await Permission.location.request();

    if (!status.isGranted) {
      return;
    }

    position = await Geolocator.getCurrentPosition();

    setState(() {
      boolStatus = true;
    });

    GoogleMapController controller = await _controller.future;

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

  Future<void> carregarPins() async {

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

          icon: item['rel_tipo_desastre'] == 'Chuva Forte'
              ? item['rel_descricao'].toString().contains('Normal')
                    ? chuvaForteYelIcon!
                    : item['rel_descricao'].toString().contains('Moderado')
                    ? chuvaForteOraIcon!
                    : item['rel_descricao'].toString().contains('Crítico')
                    ? chuvaForteRedIcon!
                    : chuvaForteBluIcon!
              : item['rel_tipo_desastre'] == 'Enchente'
              ? item['rel_descricao'].toString().contains('Normal')
                    ? inundacaoYelIcon!
                    : item['rel_descricao'].toString().contains('Moderado')
                    ? inundacaoOraIcon!
                    : item['rel_descricao'].toString().contains('Crítico')
                    ? inundacaoRedIcon!
                    : inundacaoBluIcon!
              : item['rel_tipo_desastre'] == 'Deslizamento'
              ? item['rel_descricao'].toString().contains('Normal')
                    ? deslizamentoYelIcon!
                    : item['rel_descricao'].toString().contains('Moderado')
                    ? deslizamentoOraIcon!
                    : item['rel_descricao'].toString().contains('Crítico')
                    ? deslizamentoRedIcon!
                    : deslizamentoBluIcon!
              : item['rel_tipo_desastre'] == 'Temporal'
              ? item['rel_descricao'].toString().contains('Normal')
                    ? tornadoYelIcon!
                    : item['rel_descricao'].toString().contains('Moderado')
                    ? tornadoOraIcon!
                    : item['rel_descricao'].toString().contains('Crítico')
                    ? tornadoRedIcon!
                    : tornadoBluIcon!
              : chuvaForteBluIcon!,

          infoWindow: InfoWindow(
            title: item['rel_tipo_desastre'].toString(),
          ),
        ),
      );
    }

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
    return Expanded(
        child: Stack(
          children: [
            GoogleMap(
              onMapCreated: (GoogleMapController controller) async {
                _controller.complete(controller);

                await carregarPins();
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

                onPressed: _GoToUserLocation,

                child: const Icon(
                  Icons.my_location,
                  color: Colors.white,
                ),
              ),
            ),
            abriuMarker ? PinsVisao(pinID: SelectedMarkerId, FecharPinVisao: FunctionFecharmarker,) : Container(),
          ],
        ),
      );
  }
}
