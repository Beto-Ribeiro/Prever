import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'exportador_import.dart';
import 'clima_detalhe_tela.dart';
import '../controles/controle_acessibilidade.dart';

class ClimaTela extends StatefulWidget {
  // Opcional: repassado para a tela de detalhe, para o ícone de perfil
  // conseguir trocar de página (mesmo comportamento do ContainerPerfilSuperior).
  final Function(int)? onChangePage;

  const ClimaTela({super.key, this.onChangePage});

  @override
  State<ClimaTela> createState() => _ClimaTelaState();
}

class _ClimaTelaState extends State<ClimaTela> {
  final TextEditingController cidadeController = TextEditingController();

  // Cada item do histórico guarda cidade, temperatura e descrição.
  final List<Map<String, String>> historicoClima = [];

  Future<void> buscarClima() async {
    final cidadeBusca = cidadeController.text.trim();
    if (cidadeBusca.isEmpty) return;

    final url =
        "https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(cidadeBusca)}&appid=$apiKey&units=metric&lang=pt_br";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final dados = jsonDecode(response.body);
      _adicionarResultado(
        cidade: dados["name"],
        temperatura: "${dados["main"]["temp"].round()}°",
        descricao: dados["weather"][0]["description"],
      );
    } else {
      _adicionarResultado(
        cidade: cidadeBusca,
        temperatura: "--°",
        descricao: "Cidade não encontrada",
      );
    }
  }

  Future<void> buscarClimaPorLocalizacao() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _mostrarErro("Serviço de localização desativado");
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _mostrarErro("Permissão de localização negada");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _mostrarErro("Permissão permanentemente negada");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final url =
          "https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric&lang=pt_br";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        cidadeController.clear();
        _adicionarResultado(
          cidade: dados["name"],
          temperatura: "${dados["main"]["temp"].round()}°",
          descricao: dados["weather"][0]["description"],
        );
      } else {
        _mostrarErro("Erro ao buscar clima da localização");
      }
    } catch (e) {
      _mostrarErro("Erro ao obter a localização");
    }
  }

  // Insere o novo resultado no TOPO da lista (index 0).
  void _adicionarResultado({
    required String cidade,
    required String temperatura,
    required String descricao,
  }) {
    setState(() {
      historicoClima.insert(0, {
        "cidade": cidade,
        "temperatura": temperatura,
        "descricao": descricao,
      });
    });
  }

  void _mostrarErro(String mensagem) {
    _adicionarResultado(
      cidade: "",
      temperatura: "--°",
      descricao: mensagem,
    );
  }

  final String apiKey = "b5ead541b23bfa3331c7cf3de0678295";

  @override
  void initState() {
    super.initState();
    buscarClimaPorLocalizacao();
  }

  // Abre a tela de detalhe com os dados do card clicado.
  void _abrirDetalhe(Map<String, String> resultado) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClimaDetalheTela(
          cidade: resultado["cidade"] ?? "",
          temperatura: resultado["temperatura"] ?? "",
          descricao: resultado["descricao"] ?? "",
          onChangePage: widget.onChangePage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),

              // Campo de busca
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cidadeController,
                      decoration: InputDecoration(
                        hintText: "Buscar por cidade",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onSubmitted: (valor) {
                        buscarClima();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.location_on, size: 35),
                    onPressed: () {
                      cidadeController.clear();
                      buscarClimaPorLocalizacao();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Text(
                "Buscas recentes",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: acessibilidade.corPrimaria,
                ),
              ),

              const SizedBox(height: 15),

              // Gera um card para cada resultado do histórico,
              // do mais recente (topo) para o mais antigo.
              // Cada card é clicável e abre a tela de detalhe.
              ...historicoClima.map((resultado) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(25),
                      onTap: () => _abrirDetalhe(resultado),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: acessibilidade.corSecundaria,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    resultado["cidade"] ?? "",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: acessibilidade.corPrimaria,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    resultado["temperatura"] ?? "",
                                    style: TextStyle(
                                      fontSize: 50,
                                      fontWeight: FontWeight.bold,
                                      color: acessibilidade.corPrimaria,
                                    ),
                                  ),
                                  Text(
                                    resultado["descricao"] ?? "",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: acessibilidade.corPrimaria,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              Icons.cloud,
                              size: 80,
                              color: acessibilidade.corPrimaria,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
