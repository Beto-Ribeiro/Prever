import 'package:branch1/telas/cadastro_tela.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exportador_import.dart';
import 'package:branch1/main.dart';

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

  Future<void> Login() async {
    setState(() {
      _estaCarregando = true;
    });
    try {
      String Email = _EmailController.text.trim();
      String Senha = _SenhaController.text.trim();

      if (Email.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Insira seu e-mail',
            ),
          ),
        );
        setState(() {
          _estaCarregando = false;
        });

        return;
      }
      else if (Senha.isEmpty){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Insira sua senha',
            ),
          ),
        );
        setState(() {
          _estaCarregando = false;
        });

        return;
      }

      final response =
      await Supabase.instance.client.auth.signInWithPassword(
        email: Email,
        password: Senha,
      );

      if (response.session != null) {
        print("Login realizado");
        print(response.user?.id);

        widget.onChangePage(0); // Home
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("E-mail ou senha inválidos."),
        ),
      );
      setState(() {
        _estaCarregando = false;
      });
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
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    verticalDirection: VerticalDirection.up,

                    mainAxisSize: MainAxisSize.max,

                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          25,
                          50,
                          25,
                          50,
                        ),
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height,
                        ),
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
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              spacing: 90,
                              children: [
                                GestureDetector(
                                  onTap: () {

                                  },
                                  child: const Text(
                                    "Esqueci a senha", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    widget.onChangePage(4);
                                  },
                                  child: const Text(
                                    "Não tenho uma conta prever", style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                                  ),
                                )
                              ],
                            ),
                            Container(
                              height: 50,
                              width: double.infinity,
                            ),

                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Color.fromRGBO(24, 57, 92, 1), minimumSize: Size(350, 45)),

                              onPressed: _estaCarregando ? null : Login, //MUDAR DEPOIS

                              child: _estaCarregando
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                'Acessar', style: TextStyle(color: Colors.white),
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

                        child: Image.asset(
                          "gfx/png/Image/prever.png",
                          height: 120,
                        ),
                      ),
                    ],
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
