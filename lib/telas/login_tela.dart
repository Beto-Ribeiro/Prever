import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:branch1/telas/formatadores/background_abs_code.dart';

class sLogin extends StatefulWidget {
  final Function(int) onChangePage;

  const sLogin({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<sLogin> createState() => _sLogin_State();
}

class _sLogin_State extends State<sLogin> {
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
      if (email.isEmpty || senha.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              email.isEmpty ? 'Insira seu e-mail' : 'Insira sua senha',
            ),
          ),
        );
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
      backgroundColor: Colors.blueGrey[600],

      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: AbstractBackgroundPainter(),
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
                          decoration: const BoxDecoration(
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
                                  color: Color.fromRGBO(9, 22, 46, 1),
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
                                      widget.onChangePage(10);
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
                                      widget.onChangePage(4);
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
                              Container(
                                height: 50,
                                width: double.infinity,
                              ),

                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color.fromRGBO(
                                    24,
                                    57,
                                    92,
                                    1,
                                  ),
                                  minimumSize: Size(350, 45),
                                ),

                                onPressed: _estaCarregando
                                    ? null
                                    : Login, //MUDAR DEPOIS

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
                                        style: TextStyle(color: Colors.white),
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

                          child: SvgPicture.asset("gfx/svg/Image/Prever_logo.svg", semanticsLabel: "Logo Prever",
                            height: 120,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onChangePage(5);
                  },
                  child: Icon(
                    Icons.arrow_back,
                    size: 15,
                    fontWeight: FontWeight(800),
                    color: Color.fromRGBO(228, 232, 235, 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(228, 232, 235, 0.2),
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
