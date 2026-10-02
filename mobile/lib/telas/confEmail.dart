import 'exportador_import.dart';

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
    // IMPORTANTE: Nunca registrar credenciais em logs de produção.
    debugPrint("Verificando confirmação de e-mail...");
    if (widget.email == null || widget.senha == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Erro: e-mail ou senha não foram recebidos. Tente cadastrar novamente."),
          ),
        );
      }
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

      if (!mounted) return;

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
      debugPrint("AuthException na confirmação de e-mail: ${e.statusCode}");
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    } catch (e) {
      debugPrint("Erro genérico na confirmação de e-mail");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Erro inesperado. Tente novamente."),
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
      

      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: AbstractBackgroundPainter(
                primaryColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                secondaryColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3),
                tertiaryColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              ),
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
                    padding: EdgeInsets.fromLTRB(
                      25,
                      25,
                      25,
                      25,
                    ),
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
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
                        SizedBox(
                          height: 30,
                          width: double.infinity,
                        ),
                        ElevatedButton(
                          onPressed: _verificando ? null : verificarConfirmacao,
                          child: _verificando
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text("Já confirmei!"),
                        ),
                        SizedBox(height: 10),
                        GestureDetector(
                          onTap: () {
                            widget.onChangePage(8); // Ir para tela de login
                          },
                          child: Text(
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
                    margin: EdgeInsets.fromLTRB(
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
