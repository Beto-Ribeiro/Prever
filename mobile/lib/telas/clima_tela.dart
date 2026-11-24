import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'exportador_import.dart';
import 'clima_detalhe_tela.dart';
import 'icone_clima.dart';
import '../controles/controle_acessibilidade.dart';

class _EntradaCacheClima {
  final Map<String, dynamic> dados;
  final DateTime expiraEm;

  const _EntradaCacheClima(this.dados, this.expiraEm);

  bool get valido => DateTime.now().isBefore(expiraEm);
}

class ClimaTela extends StatefulWidget {
  final Function(int)? onChangePage;

  const ClimaTela({super.key, this.onChangePage});

  @override
  State<ClimaTela> createState() => _ClimaTelaState();
}

class _ClimaTelaState extends State<ClimaTela> {
  final TextEditingController cidadeController = TextEditingController();
  final List<Map<String, dynamic>> historicoClima = [];

  static final Map<String, _EntradaCacheClima> _cacheClima = {};
  static const Duration _ttlCache = Duration(minutes: 5);
  static const Duration _timeoutRede = Duration(seconds: 12);

  String get apiKey => dotenv.env['OPENWEATHER_API_KEY'] ?? '';

  bool _carregandoLocalizacao = false;
  bool _carregandoBusca = false;

  @override
  void initState() {
    super.initState();
    buscarClimaPorLocalizacao();
  }

  @override
  void dispose() {
    cidadeController.dispose();
    super.dispose();
  }

  Future<void> buscarClima() async {
    final cidadeBusca = cidadeController.text.trim();
    if (cidadeBusca.isEmpty || _carregandoBusca) return;
    if (apiKey.isEmpty) {
      _mostrarErro(
        'Chave da API de clima (OPENWEATHER_API_KEY) não configurada.',
      );
      return;
    }

    final chaveCache = 'cidade:${cidadeBusca.toLowerCase()}';
    final emCache = _cacheClima[chaveCache];
    if (emCache != null && emCache.valido) {
      _inserirMapaResultado(emCache.dados);
      return;
    }

    setState(() => _carregandoBusca = true);

    try {
      final url =
          'https://api.openweathermap.org/data/2.5/weather?q=${Uri.encodeComponent(cidadeBusca)}&appid=$apiKey&units=metric&lang=pt_br';

      // Executa clima atual e previsão horária em paralelo para reduzir latência pela metade.
      final resultados = await Future.wait<dynamic>([
        http.get(Uri.parse(url)).timeout(_timeoutRede),
        _buscarPrevisaoHoraria(cidadeNome: cidadeBusca),
      ]);

      if (!mounted) return;

      final response = resultados[0] as http.Response;
      final previsao = resultados[1] as List<Map<String, String>>;

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body) as Map<String, dynamic>;
        final registro = {
          'cidade': dados['name']?.toString() ?? cidadeBusca,
          'temperatura': '${(dados['main']['temp'] as num).round()}°',
          'descricao': dados['weather'][0]['description']?.toString() ?? '',
          'id': dados['weather'][0]['id']?.toString() ?? '',
          'icone': dados['weather'][0]['icon'] as String? ?? '',
          'previsao': previsao,
        };
        _cacheClima[chaveCache] = _EntradaCacheClima(
          registro,
          DateTime.now().add(_ttlCache),
        );
        _inserirMapaResultado(registro);
      } else {
        _adicionarResultado(
          cidade: cidadeBusca,
          temperatura: '--°',
          descricao: 'Cidade não encontrada',
        );
      }
    } on TimeoutException {
      if (mounted) {
        _mostrarErro('Tempo esgotado ao consultar o clima. Tente novamente.');
      }
    } catch (_) {
      if (mounted) {
        _mostrarErro(
          'Sem conexão para consultar o clima. Verifique sua internet.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoBusca = false);
      }
    }
  }

  Future<void> buscarClimaPorLocalizacao() async {
    if (apiKey.isEmpty || _carregandoLocalizacao) {
      if (apiKey.isEmpty) {
        _mostrarErro(
          'Chave da API de clima (OPENWEATHER_API_KEY) não configurada.',
        );
      }
      return;
    }

    setState(() => _carregandoLocalizacao = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _mostrarErro('Serviço de localização desativado');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _mostrarErro('Permissão de localização negada');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) _mostrarErro('Permissão permanentemente negada');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      ).timeout(_timeoutRede);

      final chaveCache =
          'geo:${position.latitude.toStringAsFixed(2)},${position.longitude.toStringAsFixed(2)}';
      final emCache = _cacheClima[chaveCache];
      if (emCache != null && emCache.valido) {
        if (mounted) {
          cidadeController.clear();
          _inserirMapaResultado(emCache.dados);
        }
        return;
      }

      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$apiKey&units=metric&lang=pt_br';

      final resultados = await Future.wait<dynamic>([
        http.get(Uri.parse(url)).timeout(_timeoutRede),
        _buscarPrevisaoHoraria(
          lat: position.latitude,
          lon: position.longitude,
        ),
      ]);

      if (!mounted) return;

      final response = resultados[0] as http.Response;
      final previsao = resultados[1] as List<Map<String, String>>;

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body) as Map<String, dynamic>;
        cidadeController.clear();
        final registro = {
          'cidade': dados['name']?.toString() ?? '',
          'temperatura': '${(dados['main']['temp'] as num).round()}°',
          'descricao': dados['weather'][0]['description']?.toString() ?? '',
          'id': dados['weather'][0]['id']?.toString() ?? '',
          'icone': dados['weather'][0]['icon'] as String? ?? '',
          'previsao': previsao,
        };
        _cacheClima[chaveCache] = _EntradaCacheClima(
          registro,
          DateTime.now().add(_ttlCache),
        );
        _inserirMapaResultado(registro);
      } else {
        _mostrarErro('Erro ao buscar clima da localização');
      }
    } catch (_) {
      if (mounted) {
        _mostrarErro('Erro ao obter a localização');
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoLocalizacao = false);
      }
    }
  }

  Future<List<Map<String, String>>> _buscarPrevisaoHoraria({
    double? lat,
    double? lon,
    String? cidadeNome,
  }) async {
    try {
      final String url;
      if (lat != null && lon != null) {
        url =
            'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=$apiKey&units=metric&lang=pt_br';
      } else if (cidadeNome != null) {
        url =
            'https://api.openweathermap.org/data/2.5/forecast?q=${Uri.encodeComponent(cidadeNome)}&appid=$apiKey&units=metric&lang=pt_br';
      } else {
        return [];
      }

      final response = await http.get(Uri.parse(url)).timeout(_timeoutRede);
      if (response.statusCode != 200) return [];

      final dados = jsonDecode(response.body);
      final int timezoneOffset = dados['city']?['timezone'] ?? 0;
      final DateTime agoraLocal = DateTime.now().toUtc().add(
        Duration(seconds: timezoneOffset),
      );

      final List<dynamic> lista = dados['list'] ?? [];
      final List<Map<String, String>> previsao = [];

      for (final item in lista) {
        final int dt = item['dt'];
        final DateTime horaItemLocal = DateTime.fromMillisecondsSinceEpoch(
          dt * 1000,
          isUtc: true,
        ).add(Duration(seconds: timezoneOffset));

        if (horaItemLocal.isAfter(agoraLocal)) {
          final condicao = item['weather'][0];
          previsao.add({
            'hora': '${horaItemLocal.hour.toString().padLeft(2, '0')}h',
            'temperatura': '${(item['main']['temp'] as num).round()}°',
            'descricao': condicao['description'] ?? '',
            'id': condicao['id']?.toString() ?? '',
            'icone': condicao['icon'] as String? ?? '',
          });
        }

        if (previsao.length >= 4) break;
      }

      return previsao;
    } catch (_) {
      return [];
    }
  }

  void _inserirMapaResultado(Map<String, dynamic> registro) {
    if (!mounted) return;
    setState(() {
      historicoClima.removeWhere(
        (item) =>
            (item['cidade'] as String? ?? '').isNotEmpty &&
            item['cidade'] == registro['cidade'],
      );
      historicoClima.insert(0, Map<String, dynamic>.from(registro));
      if (historicoClima.length > 20) {
        historicoClima.removeRange(20, historicoClima.length);
      }
    });
  }

  void _adicionarResultado({
    required String cidade,
    required String temperatura,
    required String descricao,
    String? id,
    String? icone,
    List<Map<String, String>>? previsao,
  }) {
    if (!mounted) return;
    setState(() {
      historicoClima.insert(0, {
        'cidade': cidade,
        'temperatura': temperatura,
        'descricao': descricao,
        'id': id ?? '',
        'icone': icone ?? '',
        'previsao': previsao ?? <Map<String, String>>[],
      });
      if (historicoClima.length > 20) {
        historicoClima.removeRange(20, historicoClima.length);
      }
    });
  }

  void _mostrarErro(String mensagem) {
    _adicionarResultado(
      cidade: '',
      temperatura: '--°',
      descricao: mensagem,
    );
  }

  void _abrirDetalhe(Map<String, dynamic> resultado) {
    final List<Map<String, String>> previsao =
        (resultado['previsao'] as List<Map<String, String>>?) ??
        <Map<String, String>>[];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClimaDetalheTela(
          cidade: resultado['cidade'] as String? ?? '',
          temperatura: resultado['temperatura'] as String? ?? '',
          descricao: resultado['descricao'] as String? ?? '',
          idAtual: resultado['id'] as String?,
          iconeAtual: resultado['icone'] as String?,
          previsaoHoraria: previsao.isNotEmpty ? previsao : null,
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cidadeController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por cidade',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _carregandoBusca
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      onSubmitted: (_) => buscarClima(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _carregandoLocalizacao
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.location_on, size: 35),
                          onPressed: () {
                            cidadeController.clear();
                            buscarClimaPorLocalizacao();
                          },
                        ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Buscas recentes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: acessibilidade.corPrimaria,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: historicoClima.length,
                  itemBuilder: (context, index) {
                    final resultado = historicoClima[index];
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        resultado['cidade'] as String? ?? '',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: acessibilidade.corPrimaria,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        resultado['temperatura'] as String? ??
                                            '',
                                        style: TextStyle(
                                          fontSize: 50,
                                          fontWeight: FontWeight.bold,
                                          color: acessibilidade.corPrimaria,
                                        ),
                                      ),
                                      Text(
                                        resultado['descricao'] as String? ?? '',
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
                                  iconeParaClima(
                                    icone: resultado['icone'] as String?,
                                    id: resultado['id'] as String?,
                                    descricao:
                                        resultado['descricao'] as String?,
                                  ),
                                  size: 80,
                                  color: acessibilidade.corPrimaria,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
