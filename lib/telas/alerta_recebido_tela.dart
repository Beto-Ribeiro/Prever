import 'package:flutter/material.dart';
import 'package:prever/models/alerta_notificacao.dart';

class AlertaRecebidoTela extends StatelessWidget {
  final AlertaNotificacao alerta;
  const AlertaRecebidoTela({super.key, required this.alerta});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = [
      alerta.bairro,
      alerta.cidade,
    ].where((s) => s.isNotEmpty).join(', ');
    return Scaffold(
      appBar: AppBar(title: const Text('Alerta Prever')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(alerta.titulo, style: theme.textTheme.headlineSmall),
              if (alerta.severidade.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Severidade: ${alerta.severidade}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
              if (local.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(local, style: theme.textTheme.titleMedium),
              ],
              const SizedBox(height: 24),
              SelectableText(
                alerta.descricao,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const Text(
                'Mensagem recebida no momento do envio. A situação pode ter sido atualizada.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
