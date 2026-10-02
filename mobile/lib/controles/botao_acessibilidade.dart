import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'controle_acessibilidade.dart';

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
        title: Text('Sair da conta'),
        content: Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Sair'),
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
              padding: EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Acessibilidade',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'As opções abaixo se aplicam a todas as telas do app.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Letras grandes'),
                      subtitle: Text('Aumenta o tamanho do texto'),
                      value: acessibilidade.letrasGrandes,
                      onChanged: (_) => acessibilidade.toggleLetrasGrandes(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Alto contraste'),
                      subtitle: Text('Cores com maior contraste'),
                      value: acessibilidade.altoContraste,
                      onChanged: (_) => acessibilidade.toggleAltoContraste(),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Modo daltonismo'),
                      subtitle: Text('Paleta de cores adaptada'),
                      value: acessibilidade.daltonismo,
                      onChanged: (_) => acessibilidade.toggleDaltonismo(),
                    ),

                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),

                    // ── Editar perfil ─────────────────────────────────────
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Editar perfil'),
                      onTap: () {
                        Navigator.pop(context); // fecha o bottom sheet
                        widget.onEditarPerfil?.call();
                      },
                    ),

                    // ── Logout ────────────────────────────────────────────
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(
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
            padding: EdgeInsets.all(10),
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
