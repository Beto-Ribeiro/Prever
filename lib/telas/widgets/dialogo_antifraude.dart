import 'package:flutter/material.dart';
import '../services/antifraude_service.dart';

/// Widget de diálogo que aparece quando um relato é detectado como suspeito.
///
/// Permite ao usuário:
///   - Ver o motivo da suspeita apontado pela IA
///   - Confirmar o envio mesmo assim (ficará em fila de revisão admin)
///   - Cancelar e corrigir o relato
class DialogoRelatoSuspeito extends StatelessWidget {
  final ResultadoAntifraude resultado;

  /// Chamado quando o usuário confirma o envio mesmo com a suspeita.
  final VoidCallback onConfirmarEnvio;

  /// Chamado quando o usuário cancela para corrigir o relato.
  final VoidCallback onCancelar;

  const DialogoRelatoSuspeito({
    super.key,
    required this.resultado,
    required this.onConfirmarEnvio,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cabeçalho colorido ───────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF3E0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 40,
                    color: Colors.orange.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Relato Suspeito Detectado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ── Corpo do diálogo ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score de autenticidade
                Row(
                  children: [
                    const Text(
                      'Autenticidade: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    _buildScoreChip(resultado.scoreAutenticidade),
                  ],
                ),
                const SizedBox(height: 14),

                // Motivo da suspeita
                const Text(
                  '🤖 Análise da IA:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Text(
                    resultado.motivoClassificacao,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Aviso sobre revisão
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se confirmar o envio, seu relato será enviado com '
                          'baixa prioridade e precisará ser validado por um '
                          'administrador antes de ser publicado.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Botões de ação ───────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancelar,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Corrigir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirmarEnvio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Enviar Assim',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chip visual com a porcentagem de autenticidade.
  Widget _buildScoreChip(double score) {
    final porcentagem = (score * 100).toStringAsFixed(0);
    Color cor;
    if (score >= 0.7) {
      cor = Colors.green;
    } else if (score >= 0.4) {
      cor = Colors.orange;
    } else {
      cor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withOpacity(0.4)),
      ),
      child: Text(
        '$porcentagem%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: cor.shade700,
        ),
      ),
    );
  }
}

/// Widget de loading exibido enquanto o Gemini analisa o relato.
class DialogoAnalisandoRelato extends StatelessWidget {
  const DialogoAnalisandoRelato({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shield_outlined,
                size: 40,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Verificando autenticidade...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Nossa IA está analisando seu relato para garantir a qualidade das informações.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
