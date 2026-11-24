import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prever/telas/formatadores/background_abs_code.dart';
import 'package:flutter/foundation.dart';

// Logo do Google (SVG inline, não precisa adicionar arquivo ao projeto)
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class SLogin extends StatefulWidget {
  final Function(int) onChangePage;
  final Future<bool> Function(String redirectTo)? onGoogleOAuth;

  const SLogin({
    super.key,
    required this.title,
    required this.onChangePage,
    this.onGoogleOAuth,
  });

  final String title;

  @override
  State<SLogin> createState() => _SLoginState();
}

class _SLoginState extends State<SLogin> {
  bool _estaCarregando = false;

  final _EmailController = TextEditingController();
  final _SenhaController = TextEditingController();

  @override
  void dispose() {
    _EmailController.dispose();
    _SenhaController.dispose();
    super.dispose();
  }

  Future<void> loginGoogle() async {
    if (_estaCarregando) return;

    setState(() => _estaCarregando = true);

    try {
      final redirectTo = kIsWeb
          ? Uri.base.origin
          : 'com.prever.app://login-callback';
      final iniciouOAuth = widget.onGoogleOAuth != null
          ? await widget.onGoogleOAuth!(redirectTo)
          : await Supabase.instance.client.auth.signInWithOAuth(
              OAuthProvider.google,
              redirectTo: redirectTo,
            );

      if (!mounted) return;

      if (!iniciouOAuth) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o navegador para entrar com o Google.',
            ),
          ),
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro no login Google: ${e.message}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível entrar com o Google. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _estaCarregando = false);
      }
    }
  }

  Future<void> Login() async {
    if (_estaCarregando) return;

    setState(() => _estaCarregando = true);

    try {
      final email = _EmailController.text.trim();
      final senha = _SenhaController.text;

      if (email.isEmpty || senha.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                email.isEmpty ? 'Insira seu e-mail' : 'Insira sua senha',
              ),
            ),
          );
        }
        return;
      }

      final regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

      if (!regexEmail.hasMatch(email)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('E-mail inválido.'),
            ),
          );
        }
        return;
      }

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      if (!mounted) return;

      if (response.session != null) {
        _SenhaController.clear();
        widget.onChangePage(0);
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('E-mail ou senha inválidos.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _estaCarregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: AbstractBackgroundPainter(
                primaryColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                secondaryColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.3),
                tertiaryColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: Column(
                      verticalDirection: VerticalDirection.up,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Container(
                          constraints: BoxConstraints(
                            minHeight: (constraints.maxHeight - 280).clamp(
                              0.0,
                              double.infinity,
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            25,
                            50,
                            25,
                            50 + MediaQuery.paddingOf(context).bottom,
                          ),
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            // Cinza claro igual ao da imagem
                            color: Color(0xFFE5E8EB),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),

                          child: Column(
                            spacing: 15,
                            children: <Widget>[
                              Text(
                                "Bem vindo de volta!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),

                              SizedBox(
                                width: 350,
                                child: TextField(
                                  controller: _EmailController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Digite seu E-mail',
                                  ),
                                ),
                              ),

                              SizedBox(
                                width: 350,
                                child: TextField(
                                  controller: _SenhaController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    labelText: 'Digite sua senha',
                                  ),
                                ),
                              ),

                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 16,
                                runSpacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      widget.onChangePage(11);
                                    },
                                    child: const Text(
                                      "Esqueci a senha",
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),

                                  TextButton(
                                    onPressed: () {
                                      widget.onChangePage(5);
                                    },
                                    child: const Text(
                                      "Não tenho uma conta prever",
                                      style: TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(
                                height: 50,
                                width: double.infinity,
                              ),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  minimumSize: const Size(350, 45),
                                ),
                                onPressed: _estaCarregando ? null : Login,
                                child: _estaCarregando
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Acessar',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                              ),

                              const SizedBox(height: 10),

                              // Divisor "Ou tente"
                              SizedBox(
                                width: 310,
                                child: Row(
                                  children: [
                                    const Expanded(
                                      child: Divider(color: Colors.black26),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'Ou tente',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const Expanded(
                                      child: Divider(color: Colors.black26),
                                    ),
                                  ],
                                ),
                              ),

                              // Botão Google em formato de pílula
                              Semantics(
                                button: true,
                                enabled: !_estaCarregando,
                                label: 'Continuar com Google',
                                child: Material(
                                  color: const Color(0xFFE5E8EB),
                                  elevation: 6,
                                  shadowColor: Colors.black38,
                                  shape: const StadiumBorder(),
                                  child: InkWell(
                                    key: const Key('botao_login_google'),
                                    customBorder: const StadiumBorder(),
                                    onTap: _estaCarregando ? null : loginGoogle,
                                    child: SizedBox(
                                      width: 70,
                                      height: 50,
                                      child: Center(
                                        child: SvgPicture.string(
                                          _googleLogoSvg,
                                          width: 26,
                                          height: 26,
                                          semanticsLabel:
                                              'Continuar com Google',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          margin: const EdgeInsets.fromLTRB(
                            0,
                            80,
                            0,
                            80,
                          ),
                          child: SvgPicture.asset(
                            "gfx/svg/Image/Prever_logo.svg",
                            semanticsLabel: "Logo Prever",
                            height: 120,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                ElevatedButton(
                  onPressed: () {
                    widget.onChangePage(6);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    size: 15,
                    fontWeight: FontWeight(800),
                    color: Theme.of(context).colorScheme.onPrimary,
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
