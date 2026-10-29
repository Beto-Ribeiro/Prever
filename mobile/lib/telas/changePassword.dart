import 'exportador_import.dart';

class ChangePassword extends StatefulWidget {
  final String title;
  final Function(int) onChangePage;

  const ChangePassword({
    super.key,
    required this.onChangePage,
    required this.title,
  });

  @override
  State<ChangePassword> createState() => _changePassword_State();
}

class _changePassword_State extends State<ChangePassword> {
  // Controller do campo de e-mail
  final emailController = TextEditingController();

  // Cliente do Supabase
  final supabase = Supabase.instance.client;

  // Controla o CircularProgressIndicator
  bool _estaCarregando = false;

  // ---------------------------------------------------------
  // VALIDA O E-MAIL
  // ---------------------------------------------------------

  bool emailValido(String email) {
    // Regex simples para validar a estrutura básica de um e-mail
    final regexEmail = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return regexEmail.hasMatch(email);
  }

  // ---------------------------------------------------------
  // QUANDO O USUÁRIO CLICAR EM "ENVIAR"
  // ---------------------------------------------------------

  Future<void> solicitarRedefinicaoSenha() async {
    final email = emailController.text.trim();

    // Campo vazio
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Digite seu e-mail.',
          ),
        ),
      );

      return;
    }

    // E-mail inválido
    if (!emailValido(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Digite um e-mail válido.',
          ),
        ),
      );

      return;
    }

    // Começa o carregamento
    setState(() {
      _estaCarregando = true;
    });

    // Envia o e-mail
    await enviarEmail(email);
  }

  // ---------------------------------------------------------
  // ENVIA O E-MAIL DE RECUPERAÇÃO PELO SUPABASE
  // ---------------------------------------------------------

  Future<void> enviarEmail(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'prever://redefinir-senha',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Se o e-mail estiver cadastrado, você receberá '
            'as instruções para redefinir sua senha.',
          ),
        ),
      );
    }
    // Erros relacionados ao Supabase Auth
    on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erro: ${e.message}',
          ),
        ),
      );
    }
    // Outros erros
    catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível enviar o e-mail. '
            'Tente novamente.',
          ),
        ),
      );
    }
    // Executado dando certo ou errado
    finally {
      if (mounted) {
        setState(() {
          _estaCarregando = false;
        });
      }
    }
  }

  // ---------------------------------------------------------
  // LIBERA O CONTROLLER DA MEMÓRIA
  // ---------------------------------------------------------

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // INTERFACE
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fundo
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
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    verticalDirection: VerticalDirection.up,

                    mainAxisSize: MainAxisSize.max,

                    children: <Widget>[
                      // --------------------------------------------------
                      // CONTAINER BRANCO
                      // --------------------------------------------------
                      Container(
                        padding: EdgeInsets.fromLTRB(
                          25,
                          50,
                          25,
                          50,
                        ),

                        width: double.infinity,

                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height,
                        ),

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
                            // ------------------------------------------------
                            // TEXTO
                            // ------------------------------------------------
                            Text(
                              'Redefinir senha',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color.fromRGBO(
                                  24,
                                  57,
                                  92,
                                  1,
                                ),
                              ),
                            ),

                            Text(
                              'Digite o e-mail associado à sua conta. '
                              'Enviaremos um link para redefinir sua senha.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                              ),
                            ),

                            SizedBox(
                              height: 10,
                            ),

                            // ------------------------------------------------
                            // CAMPO DE E-MAIL
                            // ------------------------------------------------
                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: emailController,

                                keyboardType: TextInputType.emailAddress,

                                textInputAction: TextInputAction.done,

                                autocorrect: false,

                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Digite seu E-mail',

                                  prefixIcon: Icon(
                                    Icons.email_outlined,
                                  ),
                                ),

                                // Permite apertar "Enter"/"Concluir"
                                // no teclado para enviar
                                onSubmitted: (_) {
                                  if (!_estaCarregando) {
                                    solicitarRedefinicaoSenha();
                                  }
                                },
                              ),
                            ),

                            // ------------------------------------------------
                            // BOTÃO ENVIAR
                            // ------------------------------------------------
                            ElevatedButton(
                              onPressed: _estaCarregando
                                  ? null
                                  : solicitarRedefinicaoSenha,

                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,

                                minimumSize: const Size(
                                  139,
                                  40,
                                ),
                              ),

                              child: _estaCarregando
                                  // Carregando
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,

                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  // Normal
                                  : Text(
                                      'Enviar',
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),

                      // --------------------------------------------------
                      // LOGO
                      // --------------------------------------------------
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

                // ----------------------------------------------------------
                // BOTÃO VOLTAR
                // ----------------------------------------------------------
                Positioned(
                  top: 10,
                  left: 10,

                  child: ElevatedButton(
                    onPressed: _estaCarregando
                        ? null
                        : () {
                            widget.onChangePage(8);
                          },

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color.fromRGBO(
                        228,
                        232,
                        235,
                        0.2,
                      ),
                    ),

                    child: Icon(
                      Icons.arrow_back,

                      size: 15,

                      color: Color.fromRGBO(
                        228,
                        232,
                        235,
                        1,
                      ),
                    ),
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
