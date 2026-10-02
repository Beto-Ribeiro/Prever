import 'exportador_import.dart';

class WriteChangedPassword extends StatefulWidget {
  final Function(int) onChangePage;
  const WriteChangedPassword({
    required this.onChangePage,
    super.key,
  });

  @override
  State<WriteChangedPassword> createState() =>
      _WriteChangedPasswordState();
}

class _WriteChangedPasswordState extends State<WriteChangedPassword> {

  final supabase = Supabase.instance.client;

  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool _estaCarregando = false;

  bool _mostrarSenha = false;
  bool _mostrarConfirmarSenha = false;


  // ---------------------------------------------------------
  // VALIDA OS CAMPOS
  // ---------------------------------------------------------

  Future<void> validarSenha() async {

    final senha = senhaController.text;
    final confirmarSenha = confirmarSenhaController.text;


    // Verifica se os campos estão vazios
    if (senha.isEmpty || confirmarSenha.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha os dois campos de senha.',
          ),
        ),
      );

      return;
    }


    // Verifica se as senhas são iguais
    if (senha != confirmarSenha) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'As senhas não coincidem.',
          ),
        ),
      );

      return;
    }


    // Verifica o comprimento mínimo da senha
    if (senha.length < 6) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A senha deve ter pelo menos 6 caracteres.',
          ),
        ),
      );

      return;
    }


    // Verifica se existe uma sessão de recuperação válida
    if (supabase.auth.currentSession == null) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O link de recuperação é inválido ou expirou.',
          ),
        ),
      );

      return;
    }


    setState(() {
      _estaCarregando = true;
    });


    await alterarSenha(senha);
  }


  // ---------------------------------------------------------
  // ALTERA A SENHA NO SUPABASE
  // ---------------------------------------------------------

  Future<void> alterarSenha(String novaSenha) async {

    try {

      await supabase.auth.updateUser(
        UserAttributes(
          password: novaSenha,
        ),
      );


      if (!mounted) return;


      // Mostra confirmação
      await showDialog(
        context: context,

        barrierDismissible: false,

        builder: (context) {

          return AlertDialog(

            title: Text(
              'Senha alterada',
            ),

            content: Text(
              'Sua senha foi redefinida com sucesso. '
                  'Você poderá entrar novamente usando a nova senha.',
            ),

            actions: [

              TextButton(

                onPressed: () {
                  Navigator.of(context).pop();
                },

                child: Text(
                  'OK',
                ),
              ),

            ],
          );
        },
      );


      // Encerra a sessão criada para recuperação
      await supabase.auth.signOut();

      if (!mounted) return;

      widget.onChangePage(8);


      // Retorna para a primeira tela da navegação.
      //
      // Depois podemos substituir isso pelo seu
      // onChangePage(), caso você queira voltar
      // especificamente para a tela de login.
      Navigator.of(context).popUntil(
            (route) => route.isFirst,
      );

    }

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

    catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível alterar a senha. '
                'Tente novamente.',
          ),
        ),
      );

    }

    finally {

      if (mounted) {

        setState(() {
          _estaCarregando = false;
        });

      }

    }
  }


  // ---------------------------------------------------------
  // LIBERA OS CONTROLLERS DA MEMÓRIA
  // ---------------------------------------------------------

  @override
  void dispose() {

    senhaController.dispose();
    confirmarSenhaController.dispose();

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

          // -------------------------------------------------
          // FUNDO
          // -------------------------------------------------

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

            child: SingleChildScrollView(

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
                      minHeight:
                      MediaQuery.of(context).size.height,
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


                        // --------------------------------------------
                        // TÍTULO
                        // --------------------------------------------

                        Text(

                          'Criar nova senha',

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


                        // --------------------------------------------
                        // DESCRIÇÃO
                        // --------------------------------------------

                        Text(

                          'Digite uma nova senha para sua conta.',

                          textAlign: TextAlign.center,

                          style: TextStyle(

                            fontSize: 14,

                            color: Colors.black54,

                          ),

                        ),


                        SizedBox(
                          height: 10,
                        ),


                        // --------------------------------------------
                        // NOVA SENHA
                        // --------------------------------------------

                        SizedBox(

                          width: 350,

                          child: TextField(

                            controller: senhaController,

                            obscureText: !_mostrarSenha,

                            textInputAction:
                            TextInputAction.next,

                            decoration: InputDecoration(

                              border:
                              const OutlineInputBorder(),

                              labelText: 'Nova senha',

                              prefixIcon: Icon(
                                Icons.lock_outline,
                              ),

                              suffixIcon: IconButton(

                                onPressed: () {

                                  setState(() {

                                    _mostrarSenha =
                                    !_mostrarSenha;

                                  });

                                },

                                icon: Icon(

                                  _mostrarSenha

                                      ? Icons.visibility

                                      : Icons.visibility_off,

                                ),

                              ),

                            ),

                          ),
                        ),


                        // --------------------------------------------
                        // CONFIRMAR SENHA
                        // --------------------------------------------

                        SizedBox(

                          width: 350,

                          child: TextField(

                            controller:
                            confirmarSenhaController,

                            obscureText:
                            !_mostrarConfirmarSenha,

                            textInputAction:
                            TextInputAction.done,

                            decoration: InputDecoration(

                              border:
                              const OutlineInputBorder(),

                              labelText:
                              'Confirmar nova senha',

                              prefixIcon: Icon(
                                Icons.lock_outline,
                              ),

                              suffixIcon: IconButton(

                                onPressed: () {

                                  setState(() {

                                    _mostrarConfirmarSenha =
                                    !_mostrarConfirmarSenha;

                                  });

                                },

                                icon: Icon(

                                  _mostrarConfirmarSenha

                                      ? Icons.visibility

                                      : Icons.visibility_off,

                                ),

                              ),

                            ),


                            // Permite confirmar pelo teclado
                            onSubmitted: (_) {

                              if (!_estaCarregando) {

                                validarSenha();

                              }

                            },

                          ),
                        ),


                        SizedBox(
                          height: 10,
                        ),


                        // --------------------------------------------
                        // BOTÃO
                        // --------------------------------------------

                        ElevatedButton(

                          onPressed: _estaCarregando
                              ? null
                              : validarSenha,

                          style: ElevatedButton.styleFrom(

                            backgroundColor: Theme.of(context).colorScheme.primary,

                            minimumSize:
                            const Size(
                              180,
                              40,
                            ),

                          ),


                          child: _estaCarregando

                              ? SizedBox(

                            width: 20,

                            height: 20,

                            child:
                            CircularProgressIndicator(

                              strokeWidth: 2,

                              color: Colors.white,

                            ),
                          )

                              : Text(

                            'Redefinir senha',

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

                    child: SvgPicture.asset("gfx/svg/Image/Prever_logo.svg", semanticsLabel: "Logo Prever",

                      height: 120,

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