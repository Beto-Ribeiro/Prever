import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'controle_acessibilidade.dart';
import 'package:prever/services/notificacoes_service.dart';

class BotaoAcessibilidade extends StatefulWidget {
  /// Chamado quando o usuário toca em "Editar perfil".
  /// Passe aqui a navegação para a tela/página de edição
  /// (ex: () => widget.onChangePage(indiceDaTelaDeEdicao)).
  final VoidCallback? onEditarPerfil;

  /// Chamado depois que o logout é confirmado e o signOut() é concluído.
  /// Passe aqui a navegação até a tela de login
  /// (ex: () => widget.onChangePage(7)).
  final VoidCallback? onLogout;

  const BotaoAcessibilidade({super.key, this.onEditarPerfil, this.onLogout});

  @override
  State<BotaoAcessibilidade> createState() => _BotaoAcessibilidadeState();
}

class _BotaoAcessibilidadeState extends State<BotaoAcessibilidade>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmarLogout(BuildContext context) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmou == true) {
      await Supabase.instance.client.auth.signOut();
      widget.onLogout?.call();
    }
  }

  Future<void> _abrirPainel() async {
    // Gira a engrenagem uma volta completa ao abrir
    _controller.forward(from: 0);

    final acessibilidade = context.read<AccessibilityController>();

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return ListenableBuilder(
          listenable: acessibilidade,
          builder: (context, _) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acessibilidade',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'As opções abaixo se aplicam a todas as telas do app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Letras grandes'),
                      subtitle: const Text('Aumenta o tamanho do texto'),
                      value: acessibilidade.letrasGrandes,
                      onChanged: (_) => acessibilidade.toggleLetrasGrandes(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Alto contraste'),
                      subtitle: const Text('Cores com maior contraste'),
                      value: acessibilidade.altoContraste,
                      onChanged: (_) => acessibilidade.toggleAltoContraste(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Modo daltonismo'),
                      subtitle: const Text('Paleta de cores adaptada'),
                      value: acessibilidade.daltonismo,
                      onChanged: (_) => acessibilidade.toggleDaltonismo(),
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),

                    if (NotificacoesService.suportado)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.notifications_active_outlined,
                        ),
                        title: const Text('Cidade dos alertas'),
                        subtitle: const Text(
                          'Escolher a cidade ou desativar os avisos',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          NotificacoesService.instance.configurarCidade();
                        },
                      ),
                    // ── Editar perfil ─────────────────────────────────────
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Editar perfil'),
                      onTap: () {
                        Navigator.pop(context); // fecha o bottom sheet
                        widget.onEditarPerfil?.call();
                      },
                    ),

                    // ── Logout ────────────────────────────────────────────
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: const Text(
                        'Sair',
                        style: TextStyle(color: Colors.red),
                      ),
                      onTap: () {
                        Navigator.pop(context); // fecha o bottom sheet
                        _confirmarLogout(context);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _abrirPainel,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: RotationTransition(
              turns: _controller,
              child: Icon(
                Icons.settings,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
