import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prever/telas/formatadores/background_abs_code.dart';

class SLogin extends StatefulWidget {
  final Function(int) onChangePage;

  const SLogin({
    super.key,
    required this.title,
    required this.onChangePage,
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

  Future<void> Login() async {
    if (_estaCarregando) return;
    setState(() => _estaCarregando = true);
    try {
      final email = _EmailController.text.trim();
      final senha = _SenhaController.text;

      // Verifica campos vazios primeiro
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

      // Valida o formato do e-mail
      final regexEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
      if (!regexEmail.hasMatch(email)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('E-mail inválido.')),
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
        const SnackBar(content: Text('E-mail ou senha inválidos.')),
      );
    } finally {
      // O IndexedStack mantém esta tela montada mesmo depois de entrar.
      if (mounted) setState(() => _estaCarregando = false);
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
                          // Logo de 120 px + margens superior e inferior de 80 px.
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
                          decoration: BoxDecoration(
                            color: Colors.white,

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
                                    child: Text(
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
                                    child: Text(
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
                              SizedBox(
                                height: 50,
                                width: double.infinity,
                              ),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  minimumSize: Size(350, 45),
                                ),

                                onPressed: _estaCarregando
                                    ? null
                                    : Login, //MUDAR DEPOIS

                                child: _estaCarregando
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        'Acessar',
                                        style: TextStyle(color: Colors.white),
                                      ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          margin: EdgeInsets.fromLTRB(
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
