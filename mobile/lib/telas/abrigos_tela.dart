import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../controles/controle_acessibilidade.dart';
import 'abrigo_detalhe_tela.dart';

class AbrigosTela extends StatefulWidget {
  final String title;
  final Function(int) onChangePage;

  const AbrigosTela({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  @override
  State<AbrigosTela> createState() => _AbrigosTelaState();
}

class _AbrigosTelaState extends State<AbrigosTela> {
  // ==========================================================================
  // ESTADO
  // ==========================================================================

  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _abrigos = [];

  bool _carregando = true;

  String? _erro;

  Position? _posicaoUsuario;

  // ==========================================================================
  // INIT STATE
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  // ==========================================================================
  // CARREGA LOCALIZAÇÃO + ABRIGOS
  // ==========================================================================

  Future<void> _carregarDados() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      // Tenta obter a localização do usuário
      try {
        _posicaoUsuario = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      } catch (_) {
        // Se falhar, continua sem distância
        debugPrint('Não foi possível obter localização do usuário');
      }

      // Busca abrigos do Supabase
      final response = await supabase
          .from('Abrigo')
          .select(
            'abr_id, abr_nome, abr_tipo, abr_capacidade, abr_ocupacao, '
            'abr_coordenador, abr_coordenador_contato, abr_cidade, abr_bairro, '
            'abr_lat, abr_lng, abr_status, abr_acessibilidade, abr_aceita_pets, '
            'abr_telefone_principal, abr_telefone_secundario, abr_detalhes',
          )
          .neq('abr_status', 'inativo');

      final List<Map<String, dynamic>> abrigos = [];

      for (final row in response) {
        final double? lat = _toDouble(row['abr_lat']);
        final double? lng = _toDouble(row['abr_lng']);

        double? distanciaKm;

        if (_posicaoUsuario != null && lat != null && lng != null) {
          distanciaKm = _calcularDistanciaKm(
            _posicaoUsuario!.latitude,
            _posicaoUsuario!.longitude,
            lat,
            lng,
          );
        }

        final int capacidade = (row['abr_capacidade'] ?? 0) as int;
        final int ocupacao = (row['abr_ocupacao'] ?? 0) as int;

        abrigos.add({
          'id': row['abr_id'],
          'nome': row['abr_nome'] ?? 'Abrigo',
          'tipo': row['abr_tipo'] ?? '',
          'capacidade': capacidade,
          'ocupacao': ocupacao,
          'coordenador': row['abr_coordenador'] ?? '',
          'coordenador_contato': row['abr_coordenador_contato'] ?? '',
          'cidade': row['abr_cidade'] ?? '',
          'bairro': row['abr_bairro'] ?? '',
          'lat': lat,
          'lng': lng,
          'status': row['abr_status'] ?? 'disponivel',
          'acessibilidade': row['abr_acessibilidade'] ?? '',
          'aceita_pets': row['abr_aceita_pets'] ?? '',
          'telefone': row['abr_telefone_principal'] ?? '',
          'telefone2': row['abr_telefone_secundario'] ?? '',
          'detalhes': row['abr_detalhes'] ?? '',
          'distancia_km': distanciaKm,
        });
      }

      // Ordena por distância (mais próximos primeiro)
      abrigos.sort((a, b) {
        final dA = a['distancia_km'] as double?;
        final dB = b['distancia_km'] as double?;
        if (dA == null && dB == null) return 0;
        if (dA == null) return 1;
        if (dB == null) return -1;
        return dA.compareTo(dB);
      });

      if (!mounted) return;

      setState(() {
        _abrigos = abrigos;
        _carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar abrigos: $e');

      if (!mounted) return;

      setState(() {
        _erro = 'Não foi possível carregar os abrigos.';
        _carregando = false;
      });
    }
  }

  // ==========================================================================
  // UTILITÁRIOS
  // ==========================================================================

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  double _calcularDistanciaKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const raioTerra = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return raioTerra * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);

  String _formatarDistancia(double? km) {
    if (km == null) return '';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }

  Color _corStatus(String status) {
    switch (status) {
      case 'lotado':
        return const Color(0xFFc60202);
      case 'quase_lotado':
        return const Color(0xFFff6a00);
      default:
        return const Color(0xFF00c000);
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: Column(
          children: [
            // Espaço para o ContainerPerfilSuperior
            SizedBox(height: 60),

            // ================================================================
            // TÍTULO
            // ================================================================
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  SizedBox(height: 10),

                  Text(
                    'Abrigos',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: acessibilidade.corPrimaria,
                    ),
                  ),

                  Text(
                    'Recomendados',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: acessibilidade.corPrimaria,
                    ),
                  ),

                  SizedBox(height: 6),

                  if (_posicaoUsuario != null)
                    Text(
                      'Ordenados pela proximidade da sua localização',
                      style: TextStyle(
                        fontSize: 12,
                        color: acessibilidade.corPrimaria.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: 16),

            // ================================================================
            // CONTEÚDO
            // ================================================================
            Expanded(
              child: _carregando
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    )
                  : _erro != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: acessibilidade.corPrimaria.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            _erro!,
                            style: TextStyle(
                              color: acessibilidade.corPrimaria,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _carregarDados,
                            child: Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : _abrigos.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhum abrigo disponível no momento.',
                        style: TextStyle(
                          color: acessibilidade.corPrimaria,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregarDados,
                      color: Theme.of(context).colorScheme.primary,
                      child: ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          0,
                          20,
                          110,
                        ),
                        itemCount: _abrigos.length,
                        itemBuilder: (context, index) {
                          return _buildCardAbrigo(
                            _abrigos[index],
                            acessibilidade,
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // CARD DO ABRIGO
  // ==========================================================================

  Widget _buildCardAbrigo(
    Map<String, dynamic> abrigo,
    AccessibilityController acessibilidade,
  ) {
    final String nome = abrigo['nome'];
    final int capacidade = abrigo['capacidade'];
    final int ocupacao = abrigo['ocupacao'];
    final String status = abrigo['status'];
    final double? distancia = abrigo['distancia_km'];

    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AbrigoDetalheTela(
                abrigo: abrigo,
                posicaoUsuario: _posicaoUsuario,
              ),
            ),
          );
        },
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // ==============================================================
              // ÁREA DE IMAGEM (PLACEHOLDER)
              // ==============================================================
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 130,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.home_outlined,
                      size: 48,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),

              // ==============================================================
              // NOME DO ABRIGO
              // ==============================================================
              Positioned(
                top: 22,
                left: 16,
                right: 155,
                child: Text(
                  nome,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),

              // ==============================================================
              // DISTÂNCIA
              // ==============================================================
              if (distancia != null)
                Positioned(
                  bottom: 14,
                  left: 16,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),

                      SizedBox(width: 4),

                      Text(
                        _formatarDistancia(distancia),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

              // ==============================================================
              // CAPACIDADE + STATUS
              // ==============================================================
              Positioned(
                bottom: 14,
                right: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lotação
                    Text(
                      '$ocupacao/$capacidade',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    SizedBox(width: 10),

                    // Indicador de status
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _corStatus(status),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _corStatus(status).withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
