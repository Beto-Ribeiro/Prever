import 'package:flutter/material.dart';
import 'package:prever/models/cidade_alertas.dart';

class CidadeAlertasDialog extends StatefulWidget {
  final String cidade;
  const CidadeAlertasDialog({super.key, required this.cidade});
  @override
  State<CidadeAlertasDialog> createState() => _CidadeAlertasDialogState();
}

class _CidadeAlertasDialogState extends State<CidadeAlertasDialog> {
  late final _controller = TextEditingController(text: widget.cidade);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Alertas da sua cidade'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Receba avisos do Prever mesmo com o aplicativo fechado. '
              'Escolha a cidade dos alertas; você poderá alterá-la nas configurações do perfil.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Cidade',
                hintText: 'Ex.: São José dos Campos',
              ),
              validator: (value) {
                try {
                  topicoDaCidade(value ?? '');
                  return null;
                } on FormatException catch (e) {
                  return e.message;
                }
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Somente alertas desta cidade serão recebidos. Ao viajar, altere a cidade aqui.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Agora não'),
      ),
      if (widget.cidade.isNotEmpty)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const Text('Desativar'),
        ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, _controller.text.trim());
          }
        },
        child: const Text('Receber alertas'),
      ),
    ],
  );
}
