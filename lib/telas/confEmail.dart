import 'package:prever/telas/cadastro_tela.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exportador_import.dart';
import 'package:prever/main.dart';

class ConfEmail extends StatefulWidget {
  final Function(int) onChangePage;
  final String? email;
  final String? senha;


  const ConfEmail({
    super.key,
    required this.title,
    required this.email,
    required this.senha,
    required this.onChangePage,
  });

  final String title;

  @override
  State<ConfEmail> createState() => _confEmail_state();
}

class _confEmail_state extends State<ConfEmail> {
  bool _verificando = false;

  Future<void> verificarConfirmacao() async {
    print("Clicou em Já confirmei");
    print("EMAIL: ${widget.email}");
    print("SENHA: ${widget.senha}");
    if (widget.email == null || widget.senha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro: e-mail ou senha não foram recebidos. Tente cadastrar novamente."),
        ),
      );
      return;
    }

    setState(() {
      _verificando = true;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: widget.email!,
        password: widget.senha!,
      );

      if (response.session != null) {
        widget.onChangePage(0);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Não foi possível iniciar a sessão. Tente novamente."),
          ),
        );
      }
    } on AuthException catch (e) {
      print("AuthException: ${e.message} | statusCode: ${e.statusCode}");
      String mensagem;
      // Supabase returns "Email not confirmed" when email is unverified
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.message.toLowerCase().contains('email não confirmado')) {
        mensagem = "E-mail ainda não confirmado. Verifique sua caixa de entrada e spam.";
      } else if (e.message.toLowerCase().contains('invalid login credentials') ||
          e.message.toLowerCase().contains('invalid')) {
        mensagem = "Credenciais inválidas. Tente cadastrar novamente.";
      } else {
        mensagem = "Erro: ${e.message}";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    } catch (e) {
      print("Erro genérico: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro inesperado: $e"),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _verificando = false;
        });
      }
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
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Column(
                verticalDirection: VerticalDirection.up,

                mainAxisSize: MainAxisSize.max,

                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      25,
                      25,
                      25,
                      25,
                    ),
                    width: double.infinity,
                    height: 300,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 35,
                          children: <Widget>[
                            Text("Confirme seu e-mail de cadastro", style: TextStyle(fontSize: 20, fontWeight: FontWeight(900)),)
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 35,
                          children: <Widget>[
                            Text("para prosseguir", style: TextStyle(fontSize: 20, fontWeight: FontWeight(900)),)
                          ],
                        ),
                        Container(
                          height: 30,
                          width: double.infinity,
                        ),
                        ElevatedButton(
                          onPressed: _verificando ? null : verificarConfirmacao,
                          child: _verificando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Já confirmei!"),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            widget.onChangePage(7); // Ir para tela de login
                          },
                          child: const Text(
                            "Ir para Login",
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              color: Colors.blueGrey,
                              decoration: TextDecoration.underline,
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
                      350,
                    ),

                    child: SvgPicture.asset("gfx/svg/Image/Prever_logo.svg", semanticsLabel: "Logo Prever",
                      height: 60,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
