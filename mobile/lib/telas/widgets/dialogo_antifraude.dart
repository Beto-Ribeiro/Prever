import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/antifraude_service.dart';
import '../../controles/controle_acessibilidade.dart';

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
    final acessibilidade = context.watch<AccessibilityController>();
    final corPrincipal = acessibilidade.corPrimaria;
    final fundo = acessibilidade.fundo;
    final escala = acessibilidade.escalaFonte;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: corPrincipal.withValues(alpha: 0.2), width: 2),
      ),
      backgroundColor: fundo,
      contentPadding: EdgeInsets.zero,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cabeçalho ───────────────────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: corPrincipal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Column(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 40 * escala,
                  color: Color(0xFFC1272D), // Cor de alerta do sistema
                ),
                SizedBox(height: 12),
                Text(
                  'Atenção ao Relato',
                  style: TextStyle(
                    fontSize: 18 * escala,
                    fontWeight: FontWeight.bold,
                    color: corPrincipal,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // ── Corpo do diálogo ─────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Score de autenticidade
                Row(
                  children: [
                    Text(
                      'Autenticidade: ',
                      style: TextStyle(
                        fontSize: 14 * escala,
                        fontWeight: FontWeight.w600,
                        color: corPrincipal,
                      ),
                    ),
                    _buildScoreChip(resultado.scoreAutenticidade, escala),
                  ],
                ),
                SizedBox(height: 16),

                // Motivo da suspeita com o Nimbo
                Row(
                  children: [
                    Image.asset(
                      'gfx/png/Image/nimbo_icon.png',
                      width: 24 * escala,
                      height: 24 * escala,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.smart_toy_outlined,
                        color: corPrincipal,
                        size: 24 * escala,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Análise do Nimbo:',
                        style: TextStyle(
                          fontSize: 14 * escala,
                          fontWeight: FontWeight.bold,
                          color: corPrincipal,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: corPrincipal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: corPrincipal.withValues(alpha: 0.1)),
                  ),
                  child: Text(
                    resultado.motivoClassificacao,
                    style: TextStyle(
                      fontSize: 13 * escala,
                      color: corPrincipal,
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: 16),

                // Aviso sobre revisão
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFC1272D).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFFC1272D).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFC1272D), size: 18 * escala),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Se confirmar o envio, seu relato será enviado com '
                          'baixa prioridade e precisará ser validado por um '
                          'administrador antes de ser publicado.',
                          style: TextStyle(
                            fontSize: 12 * escala,
                            color: corPrincipal,
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
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancelar,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: corPrincipal.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Corrigir',
                      style: TextStyle(
                        fontSize: 14 * escala,
                        fontWeight: FontWeight.bold,
                        color: corPrincipal,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirmarEnvio,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFC1272D),
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Enviar Assim',
                      style: TextStyle(
                        fontSize: 14 * escala,
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
  Widget _buildScoreChip(double score, double escala) {
    final porcentagem = (score * 100).toStringAsFixed(0);
    Color cor;
    if (score >= 0.7) {
      cor = Colors.green;
    } else if (score >= 0.4) {
      cor = Colors.orange;
    } else {
      cor = Color(0xFFC1272D);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$porcentagem%',
        style: TextStyle(
          fontSize: 13 * escala,
          fontWeight: FontWeight.bold,
          color: cor,
        ),
      ),
    );
  }
}

/// Widget de loading exibido enquanto o Nimbo analisa o relato.
class DialogoAnalisandoRelato extends StatelessWidget {
  const DialogoAnalisandoRelato({super.key});

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();
    final corPrincipal = acessibilidade.corPrimaria;
    final fundo = acessibilidade.fundo;
    final escala = acessibilidade.escalaFonte;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: corPrincipal.withValues(alpha: 0.2), width: 2),
      ),
      backgroundColor: fundo,
      content: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: corPrincipal.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'gfx/png/Image/nimbo_icon.png',
                width: 40 * escala,
                height: 40 * escala,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.smart_toy_outlined,
                  color: corPrincipal,
                  size: 40 * escala,
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'O Nimbo está verificando...',
              style: TextStyle(
                fontSize: 16 * escala,
                fontWeight: FontWeight.bold,
                color: corPrincipal,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Nossa IA está analisando seu relato para garantir a qualidade das informações.',
              style: TextStyle(
                fontSize: 13 * escala,
                color: corPrincipal.withValues(alpha: 0.8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            LinearProgressIndicator(
              backgroundColor: corPrincipal.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC1272D)),
            ),
          ],
        ),
      ),
    );
  }
}
