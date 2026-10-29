import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controles/controle_acessibilidade.dart';

class AbrigoDetalheTela extends StatelessWidget {
  final Map<String, dynamic> abrigo;
  final Position? posicaoUsuario;

  const AbrigoDetalheTela({
    super.key,
    required this.abrigo,
    this.posicaoUsuario,
  });

  // ==========================================================================
  // UTILITÁRIOS
  // ==========================================================================

  Color _corStatus(String status) {
    switch (status) {
      case 'lotado':
        return Color(0xFFc60202);
      case 'quase_lotado':
        return Color(0xFFff6a00);
      default:
        return Color(0xFF00c000);
    }
  }

  String _labelStatus(String status) {
    switch (status) {
      case 'lotado':
        return 'Lotado';
      case 'quase_lotado':
        return 'Quase lotado';
      case 'inativo':
        return 'Inativo';
      default:
        return 'Disponível';
    }
  }

  // ==========================================================================
  // ABRIR GOOGLE MAPS COM ROTA
  // ==========================================================================

  Future<void> _abrirRotaGoogleMaps(BuildContext context) async {
    final double? destLat = abrigo['lat'] as double?;
    final double? destLng = abrigo['lng'] as double?;

    if (destLat == null || destLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Localização do abrigo não disponível.'),
          backgroundColor: Color(0xFFc60202),
        ),
      );
      return;
    }

    String url;

    if (posicaoUsuario != null) {
      // Rota da posição atual até o abrigo
      url =
          'https://www.google.com/maps/dir/'
          '${posicaoUsuario!.latitude},${posicaoUsuario!.longitude}/'
          '$destLat,$destLng';
    } else {
      // Sem posição do usuário, abre somente o destino
      url =
          'https://www.google.com/maps/search/?api=1'
          '&query=$destLat,$destLng';
    }

    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir o Google Maps.'),
            backgroundColor: Color(0xFFc60202),
          ),
        );
      }
    }
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    final String nome = abrigo['nome'] ?? 'Abrigo';
    final int capacidade = abrigo['capacidade'] ?? 0;
    final int ocupacao = abrigo['ocupacao'] ?? 0;
    final String status = abrigo['status'] ?? 'disponivel';
    final String coordenador = abrigo['coordenador'] ?? '';
    final String coordenadorContato = abrigo['coordenador_contato'] ?? '';
    final String cidade = abrigo['cidade'] ?? '';
    final String bairro = abrigo['bairro'] ?? '';
    final String tipo = abrigo['tipo'] ?? '';
    final String acessibilidadeInfo = abrigo['acessibilidade'] ?? '';
    final String aceitaPets = abrigo['aceita_pets'] ?? '';
    final String telefone = abrigo['telefone'] ?? '';
    final String telefone2 = abrigo['telefone2'] ?? '';
    final String detalhes = abrigo['detalhes'] ?? '';

    // Monta endereço
    final List<String> partesEndereco = [];
    if (bairro.isNotEmpty) partesEndereco.add(bairro);
    if (cidade.isNotEmpty) partesEndereco.add(cidade);
    final String endereco = partesEndereco.isNotEmpty
        ? partesEndereco.join(', ')
        : 'Endereço não informado';

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: Column(
          children: [
            // ================================================================
            // HEADER
            // ================================================================
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              padding: EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ================================================================
            // CONTEÚDO
            // ================================================================
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 14),

                    // ========================================================
                    // CARD PRINCIPAL
                    // ========================================================
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // NOME + IMAGEM
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  nome,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                              ),

                              SizedBox(width: 14),

                              Container(
                                width: 110,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.home_outlined,
                                    size: 40,
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 18),

                          // COORDENADOR + CAPACIDADE
                          Row(
                            children: [
                              // Coordenador
                              if (coordenador.isNotEmpty)
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: 18,
                                        color: Colors.white.withValues(
                                          alpha: 0.5,
                                        ),
                                      ),

                                      SizedBox(width: 6),

                                      Flexible(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Responsável:',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.5,
                                                ),
                                                fontSize: 11,
                                              ),
                                            ),
                                            Text(
                                              coordenador,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // Capacidade
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '$ocupacao/$capacidade',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Capacidade',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          SizedBox(height: 18),

                          // ENDEREÇO
                          Text(
                            'Próximo de você, $endereco.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 20),

                    // ========================================================
                    // STATUS
                    // ========================================================
                    _buildInfoRow(
                      icon: Icons.circle,
                      iconColor: _corStatus(status),
                      label: 'Status',
                      value: _labelStatus(status),
                      acessibilidade: acessibilidade,
                    ),

                    // ========================================================
                    // TIPO
                    // ========================================================
                    if (tipo.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.category_outlined,
                        label: 'Tipo de instalação',
                        value: tipo,
                        acessibilidade: acessibilidade,
                      ),

                    // ========================================================
                    // ACESSIBILIDADE
                    // ========================================================
                    if (acessibilidadeInfo.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.accessible_outlined,
                        label: 'Acessibilidade',
                        value: acessibilidadeInfo,
                        acessibilidade: acessibilidade,
                      ),

                    // ========================================================
                    // ACEITA PETS
                    // ========================================================
                    if (aceitaPets.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.pets_outlined,
                        label: 'Aceita pets',
                        value: aceitaPets,
                        acessibilidade: acessibilidade,
                      ),

                    // ========================================================
                    // TELEFONE
                    // ========================================================
                    if (telefone.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Telefone',
                        value: telefone,
                        acessibilidade: acessibilidade,
                      ),

                    if (telefone2.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Telefone secundário',
                        value: telefone2,
                        acessibilidade: acessibilidade,
                      ),

                    // ========================================================
                    // CONTATO COORDENADOR
                    // ========================================================
                    if (coordenadorContato.isNotEmpty)
                      _buildInfoRow(
                        icon: Icons.contact_phone_outlined,
                        label: 'Contato do coordenador',
                        value: coordenadorContato,
                        acessibilidade: acessibilidade,
                      ),

                    // ========================================================
                    // DETALHES
                    // ========================================================
                    if (detalhes.isNotEmpty) ...[
                      SizedBox(height: 12),

                      Text(
                        'Detalhes',
                        style: TextStyle(
                          color: acessibilidade.corPrimaria,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        detalhes,
                        style: TextStyle(
                          color: acessibilidade.corPrimaria.withValues(
                            alpha: 0.7,
                          ),
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],

                    SizedBox(height: 30),

                    // ========================================================
                    // BOTÃO GOOGLE MAPS
                    // ========================================================
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: () => _abrirRotaGoogleMaps(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 6,
                        ),
                        icon: Icon(Icons.directions, size: 24),
                        label: Text(
                          'Abrir rota no Google Maps',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // WIDGET DE LINHA DE INFORMAÇÃO
  // ==========================================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required AccessibilityController acessibilidade,
    Color? iconColor,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color:
                iconColor ?? acessibilidade.corPrimaria.withValues(alpha: 0.5),
          ),

          SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: acessibilidade.corPrimaria.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),

                SizedBox(height: 2),

                Text(
                  value,
                  style: TextStyle(
                    color: acessibilidade.corPrimaria,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
