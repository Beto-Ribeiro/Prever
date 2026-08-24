import 'dart:async';
import 'package:branch1/services/relatos_proximos_service.dart';

import 'package:branch1/telas/login_tela.dart';
import 'package:branch1/services/chatbot_service.dart';
import 'package:flutter/material.dart';
import 'exportador_import.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';


class TelaPrincipal extends StatefulWidget {
  const TelaPrincipal({super.key});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}


class _TelaPrincipalState extends State<TelaPrincipal>
    with SingleTickerProviderStateMixin {

  // ==========================================================================
  // SUPABASE
  // ==========================================================================

  final supabase = Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;


  // ==========================================================================
  // DADOS DO USUÁRIO
  // ==========================================================================

  String nome = '';

  bool carregando = true;

  String tipoUsuario = '';

  bool estalogado = false;


  // ==========================================================================
  // NAVEGAÇÃO
  // ==========================================================================

  late List<Widget> _telas;

  late int _currentIndex;
  int _solicitacaoRelato = 0;

  void _abrirRelatoNoMapa(RelatoProximo relato) {
    setState(() {
      _telas[1] = Maps_alertas(
        title: 'Mapa de alertas',
        onChangePage: changePage,
        relatoSelecionado: relato,
        solicitacaoRelato: ++_solicitacaoRelato,
      );
      _currentIndex = 1;
    });
  }


  // ==========================================================================
  // CADASTRO
  // ==========================================================================

  String? emailCadastro;

  String? senhaCadastro;


  // ==========================================================================
  // ANIMAÇÃO DO BOTÃO NIMBO
  // ==========================================================================

  late final AnimationController _nimboAnimController;

  late final Animation<double> _nimboScaleAnim;


  final List<IconData> _icones = [
    Icons.warning_amber_rounded,
    Icons.location_on_outlined,
    Icons.flag_outlined,
    Icons.cloud_queue,
  ];


  // ==========================================================================
  // INIT STATE
  // ==========================================================================

  @override
  void initState() {
    super.initState();


    // ------------------------------------------------------------------------
    // DEFINE QUAL SERÁ A PRIMEIRA TELA
    //
    // Sem usuário:
    // índice 5 = Landing Page
    //
    // Com usuário:
    // índice 0 = Home
    // ------------------------------------------------------------------------

    _currentIndex =
    supabase.auth.currentUser == null
        ? 5
        : 0;


    // ------------------------------------------------------------------------
    // ANIMAÇÃO DO BOTÃO NIMBO
    // ------------------------------------------------------------------------

    _nimboAnimController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 120,
      ),
      lowerBound: 0.88,
      upperBound: 1.0,
    )..value = 1.0;

    _nimboScaleAnim = _nimboAnimController;


    // ------------------------------------------------------------------------
    // PRIMEIRO CRIA TODAS AS TELAS
    // ------------------------------------------------------------------------

    _inicializarTelas();


    // ------------------------------------------------------------------------
    // COMEÇA A ESCUTAR EVENTOS DE AUTENTICAÇÃO DO SUPABASE
    // ------------------------------------------------------------------------

    _ouvirAutenticacao();


    // ------------------------------------------------------------------------
    // PEDE PERMISSÃO DE LOCALIZAÇÃO
    // ------------------------------------------------------------------------

    _Ask_for_permission();
  }


  // ==========================================================================
  // ESCUTA EVENTOS DO SUPABASE
  // ==========================================================================

  void _ouvirAutenticacao() {

    // ------------------------------------------------------------------------
    // SE O APP JÁ ABRIU COM USUÁRIO LOGADO,
    // CARREGA OS DADOS
    // ------------------------------------------------------------------------

    if (supabase.auth.currentUser != null) {
      carregarDados();
    }


    // ------------------------------------------------------------------------
    // LISTENER DE AUTENTICAÇÃO
    // ------------------------------------------------------------------------

    _authSubscription =
        supabase.auth.onAuthStateChange.listen(

              (data) {

            if (!mounted) {
              return;
            }


            // ====================================================================
            // RECUPERAÇÃO DE SENHA
            // ====================================================================
            //
            // Esse evento acontece quando:
            //
            // 1. Usuário pediu recuperação
            // 2. Recebeu o e-mail
            // 3. Clicou no link
            // 4. Supabase validou o link
            // 5. O deep link abriu o aplicativo
            //
            // ====================================================================

            if (data.event == AuthChangeEvent.passwordRecovery) {

              debugPrint(
                '=== RECUPERAÇÃO DE SENHA DETECTADA ===',
              );

              setState(() {

                // ---------------------------------------------------------------
                // ÍNDICE 11:
                // writeChangedPassword
                // ---------------------------------------------------------------

                _currentIndex = 11;

              });

              return;
            }


            // ====================================================================
            // EXISTE UMA SESSÃO
            // ====================================================================

            if (data.session != null) {

              // Evita ficar consultando o perfil desnecessariamente
              // em eventos como tokenRefreshed.

              if (
              data.event == AuthChangeEvent.initialSession ||
                  data.event == AuthChangeEvent.signedIn ||
                  data.event == AuthChangeEvent.userUpdated
              ) {

                carregarDados();

              }

            }

          },


          // ======================================================================
          // ERRO NO STREAM DE AUTENTICAÇÃO
          // ======================================================================

          onError: (error, stackTrace) {

            debugPrint(
              'Erro no Auth do Supabase: $error',
            );

          },

        );
  }


  // ==========================================================================
  // CARREGA DADOS DO USUÁRIO
  // ==========================================================================

  Future<void> carregarDados() async {

    try {

      final userId = supabase.auth.currentUser?.id;

      debugPrint(
        '=== USER ID: $userId ===',
      );


      // ----------------------------------------------------------------------
      // USUÁRIO NÃO ENCONTRADO
      // ----------------------------------------------------------------------

      if (userId == null) {

        debugPrint(
          '=== USUÁRIO NULO ===',
        );

        if (mounted) {

          setState(() {
            carregando = false;
          });

        }

        return;
      }


      // ======================================================================
      // PERFIL
      // ======================================================================

      try {

        final perfil = await supabase
            .from('Perfis')
            .select()
            .eq(
          'prf_id',
          userId,
        )
            .limit(1)
            .single();


        debugPrint(
          '=== PERFIL OK: $perfil ===',
        );


        if (!mounted) {
          return;
        }


        setState(() {

          nome =
              perfil['prf_nome'] ?? '';

          tipoUsuario =
              perfil['prf_tipo'] ?? '';

          carregando = false;

        });

      }

      catch (e) {

        debugPrint(
          '=== ERRO PERFIL: $e ===',
        );


        if (mounted) {

          setState(() {
            carregando = false;
          });

        }

      }

    }

    catch (e) {

      debugPrint(
        '=== ERRO AO CARREGAR DADOS: $e ===',
      );


      if (mounted) {

        setState(() {
          carregando = false;
        });

      }

    }
  }


  // ==========================================================================
  // INICIALIZA TODAS AS TELAS
  // ==========================================================================

  void _inicializarTelas() {

    _telas = [

      // ======================================================================
      // 0 - HOME / SOS
      // ======================================================================

      Home(
        title: "SOS",
        onChangePage: changePage,
      ),


      // ======================================================================
      // 1 - MAPA DE ALERTAS
      // ======================================================================

      Maps_alertas(
        title: "SOS",
        onChangePage: changePage,
      ),


      // ======================================================================
      // 2 - RELATOS
      // ======================================================================

      Relatos_tela(
        title: "Relato",
        onChangePage: changePage,
      ),


      // ======================================================================
      // 3 - CLIMA
      // ======================================================================

      ClimaTela(),


      // ======================================================================
      // 4 - CADASTRO
      // ======================================================================

      Cadastro_tela(

        title: "Cadastro",

        onChangePage: changePage,

        onCadastroPendente: (email, senha) {

          debugPrint(
            "RECEBI EMAIL NA TELA PRINCIPAL: $email",
          );

          debugPrint(
            "RECEBI SENHA NA TELA PRINCIPAL: $senha",
          );


          setState(() {

            emailCadastro = email;

            senhaCadastro = senha;


            // ---------------------------------------------------------------
            // Abre confirmação de e-mail
            // ---------------------------------------------------------------

            _currentIndex = 6;


            // ---------------------------------------------------------------
            // Recria somente a tela 6 com os dados
            // que acabaram de chegar.
            // ---------------------------------------------------------------

            _telas[6] = confEmail(

              title: "Confirmação",

              onChangePage: changePage,

              email: emailCadastro,

              senha: senhaCadastro,

            );

          });

        },

      ),


      // ======================================================================
      // 5 - LANDING PAGE LOGIN/CADASTRO
      // ======================================================================

      sLogCad(
        title: "Landing Page",
        onChangePage: changePage,
      ),


      // ======================================================================
      // 6 - CONFIRMAÇÃO DE E-MAIL
      // ======================================================================

      confEmail(

        title: "Confirmação",

        onChangePage: changePage,

        email: emailCadastro,

        senha: senhaCadastro,

      ),


      // ======================================================================
      // 7 - LOGIN
      // ======================================================================

      sLogin(
        title: "Login",
        onChangePage: changePage,
      ),


      // ======================================================================
      // 8 - PERFIL
      // ======================================================================

      TelaPerfil(
        title: "Perfil",
        onChangePage: changePage,
      ),


      // ======================================================================
      // 9 - NIMBO
      // ======================================================================

      ChatbotTela(
        title: 'Nimbo',
        onChangePage: changePage,
      ),


      // ======================================================================
      // 10 - SOLICITAR REDEFINIÇÃO DE SENHA
      //
      // Aqui o usuário digita o e-mail.
      // ======================================================================

      changePassword(
        title: 'Change Password',
        onChangePage: changePage,
      ),


      // ======================================================================
      // 11 - ESCREVER A NOVA SENHA
      //
      // Essa é a tela aberta depois que o usuário
      // clica no link recebido no e-mail.
      // ======================================================================

      writeChangedPassword(
        onChangePage: changePage,
      ),

      //=======================================================================
      //12 - EDITAR PERFIL

      EditarPerfilTela(title: 'editar', onChangePage: changePage)
    ];
  }


  // ==========================================================================
  // PERMISSÃO DE LOCALIZAÇÃO
  // ==========================================================================

  Future<void> _Ask_for_permission() async {

    PermissionStatus status =
    await Permission.location.request();


    if (status.isGranted) {

      Position position =
      await Geolocator.getCurrentPosition();


      debugPrint(
        'Localização obtida: '
            '${position.latitude}, '
            '${position.longitude}',
      );

    }

    else if (
    status.isDenied ||
        status.isPermanentlyDenied
    ) {

      debugPrint(
        'Permissão de localização negada pelo usuário.',
      );

    }

  }


  // ==========================================================================
  // TROCA DE PÁGINA
  // ==========================================================================

  void changePage(int index) {

    if (!mounted) {
      return;
    }


    // Proteção contra índices inválidos
    if (
    index < 0 ||
        index >= _telas.length
    ) {

      debugPrint(
        'Índice de tela inválido: $index',
      );

      return;
    }


    setState(() {

      _currentIndex = index;

      // O IndexedStack preserva o estado: recarrega os dados ao abrir o perfil.
      if (index == 8) {
        _telas[8] = TelaPerfil(key: UniqueKey(), title: 'Perfil',
            onChangePage: changePage);
      } else if (index == 12) {
        _telas[12] = EditarPerfilTela(key: UniqueKey(), title: 'Editar perfil',
            onChangePage: changePage);
      }

    });

  }


  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {

    // ------------------------------------------------------------------------
    // PARA DE ESCUTAR EVENTOS DE AUTENTICAÇÃO
    // ------------------------------------------------------------------------

    _authSubscription?.cancel();


    // ------------------------------------------------------------------------
    // DESTROI ANIMAÇÃO
    // ------------------------------------------------------------------------

    _nimboAnimController.dispose();


    super.dispose();
  }


  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {

    // ========================================================================
    // ESCONDE A BARRA NAS TELAS FORA DA NAVEGAÇÃO PRINCIPAL
    //
    // 0 = Home
    // 1 = Mapas
    // 2 = Relatos
    // 3 = Clima
    //
    // 4 em diante = Cadastro, Login, Perfil, Nimbo,
    // recuperação de senha etc.
    // ========================================================================

    final bool ocultarNav =
        _currentIndex >= 4;


    // ========================================================================
    // VERIFICA SE ESTÁ NO NIMBO
    // ========================================================================

    final bool noNimbo =
        _currentIndex == 9;


    return Scaffold(

      extendBody: true,


      // ======================================================================
      // BODY
      // ======================================================================

      body: Stack(

        children: [

          // ==================================================================
          // CONTEÚDO PRINCIPAL
          // ==================================================================

          Padding(

            padding:

            ocultarNav

                ? const EdgeInsets.only(
              top: 0,
            )

                : _currentIndex == 0

                ? const EdgeInsets.only(
              top: 0,
            )

                : const EdgeInsets.only(
              top: 30,
            ),


            child: IndexedStack(

              index: _currentIndex,

              children: [
                Home(title: 'SOS', onChangePage: changePage,
                    onAbrirRelato: _abrirRelatoNoMapa,
                    ativa: _currentIndex == 0),
                ..._telas.skip(1),
              ],

            ),

          ),


          // ==================================================================
          // BOTÃO FLUTUANTE NIMBO
          //
          // Só aparece nas telas principais.
          // ==================================================================

          if (!ocultarNav && !noNimbo)

            Positioned(

              bottom: 80,

              right: 20,


              child: ScaleTransition(

                scale: _nimboScaleAnim,


                child: GestureDetector(

                  // ----------------------------------------------------------
                  // PRESSIONOU
                  // ----------------------------------------------------------

                  onTapDown: (_) {

                    _nimboAnimController.reverse();

                  },


                  // ----------------------------------------------------------
                  // SOLTOU
                  // ----------------------------------------------------------

                  onTapUp: (_) {

                    _nimboAnimController.forward();

                    changePage(9);

                  },


                  // ----------------------------------------------------------
                  // CANCELOU
                  // ----------------------------------------------------------

                  onTapCancel: () {

                    _nimboAnimController.forward();

                  },


                  child: Container(

                    width: 64,

                    height: 64,


                    decoration: BoxDecoration(

                      color:
                      const Color(
                        0xFF0B1426,
                      ),


                      borderRadius:
                      const BorderRadius.only(

                        topLeft:
                        Radius.circular(32),

                        topRight:
                        Radius.circular(32),

                        bottomLeft:
                        Radius.circular(32),

                        bottomRight:
                        Radius.circular(4),

                      ),


                      border: Border.all(

                        color:
                        Colors.white.withOpacity(
                          0.15,
                        ),

                        width: 2,

                      ),


                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors.black.withOpacity(
                            0.35,
                          ),

                          blurRadius: 12,

                          offset:
                          const Offset(
                            0,
                            4,
                          ),

                        ),

                      ],

                    ),


                    child: Padding(

                      padding:
                      const EdgeInsets.all(
                        8,
                      ),


                      child: Image.asset(

                        'gfx/png/Image/nimbo_icon.png',

                        fit: BoxFit.contain,

                        isAntiAlias: true,

                      ),

                    ),

                  ),

                ),

              ),

            ),


          // ==================================================================
          // PERFIL SUPERIOR
          // ==================================================================

          if (!ocultarNav)

            SafeArea(

              child: ContainerPerfilSuperior(

                onChangePage: changePage,

                nome: nome,

              ),

            ),

        ],

      ),


      // ======================================================================
      // BOTTOM NAVIGATION
      // ======================================================================

      bottomNavigationBar:

      ocultarNav || noNimbo

          ? null

          : CustomAnimatedBottomBar(

        currentIndex:
        _currentIndex,

        icones:
        _icones,


        onTap: (index) {

          changePage(index);

        },

      ),

    );
  }
}


// ============================================================================
// WIDGET CUSTOMIZADO: BARRA INFERIOR ANIMADA
// ============================================================================

class CustomAnimatedBottomBar
    extends StatelessWidget {

  final int currentIndex;

  final List<IconData> icones;

  final Function(int) onTap;


  const CustomAnimatedBottomBar({

    super.key,

    required this.currentIndex,

    required this.icones,

    required this.onTap,

  });


  final Color corFundoMenu =
  const Color(
    0xFF0B1426,
  );


  final Color corIconeInativo =
  const Color(
    0xFF4A5568,
  );


  @override
  Widget build(BuildContext context) {

    return SizedBox(

      height: 90,


      child: TweenAnimationBuilder<double>(

        tween: Tween<double>(

          begin:
          currentIndex.toDouble(),

          end:
          currentIndex.toDouble(),

        ),


        duration:
        const Duration(
          milliseconds: 350,
        ),


        curve:
        Curves.easeInOutBack,


        builder:
            (
            context,
            value,
            child,
            ) {

          final double segmentWidth =
              MediaQuery.of(context)
                  .size
                  .width /
                  icones.length;


          final double buttonLeftOffset =
              (segmentWidth * value) +
                  (segmentWidth / 2) -
                  28;


          return Stack(

            children: [

              // ==============================================================
              // BARRA
              // ==============================================================

              Positioned(

                bottom: 0,

                left: 0,

                right: 0,


                child: ClipPath(

                  clipper: MenuClipper(

                    value,

                    icones.length,

                  ),


                  child: Container(

                    height: 70,

                    color:
                    corFundoMenu,


                    child: Row(

                      mainAxisAlignment:
                      MainAxisAlignment
                          .spaceAround,


                      children:
                      List.generate(

                        icones.length,

                            (index) {

                          return GestureDetector(

                            behavior:
                            HitTestBehavior
                                .opaque,


                            onTap: () {

                              onTap(
                                index,
                              );

                            },


                            child:
                            SizedBox(

                              width:
                              segmentWidth,

                              height:
                              70,


                              child:
                              Icon(

                                icones[
                                index],

                                color:
                                currentIndex ==
                                    index

                                    ? Colors
                                    .transparent

                                    : corIconeInativo,

                                size: 28,

                              ),

                            ),

                          );

                        },

                      ),

                    ),

                  ),

                ),

              ),


              // ==============================================================
              // BOTÃO CENTRAL ANIMADO
              // ==============================================================

              Positioned(

                top: 0,

                left:
                buttonLeftOffset,


                child:
                GestureDetector(

                  onTap: () {

                    onTap(
                      currentIndex,
                    );

                  },


                  child:
                  Container(

                    width: 56,

                    height: 56,


                    decoration:
                    BoxDecoration(

                      color:
                      corFundoMenu,

                      shape:
                      BoxShape.circle,

                      border:
                      Border.all(

                        color:
                        Colors.white,

                        width: 3.5,

                      ),

                    ),


                    child:
                    Icon(

                      icones[
                      currentIndex],

                      color:
                      Colors.white,

                      size: 28,

                    ),

                  ),

                ),

              ),

            ],

          );

        },

      ),

    );
  }
}


// ============================================================================
// MATEMÁTICA DO RECORTE (NOTCH)
// ============================================================================

class MenuClipper
    extends CustomClipper<Path> {

  final double position;

  final int segments;


  MenuClipper(
      this.position,
      this.segments,
      );


  @override
  Path getClip(Size size) {

    final path =
    Path();


    final double width =
        size.width;


    final double height =
        size.height;


    final double segmentWidth =
        width / segments;


    final double notchCenter =
        (segmentWidth * position) +
            (segmentWidth / 2);


    path.lineTo(
      notchCenter - 45,
      0,
    );


    path.cubicTo(

      notchCenter - 20,

      0,

      notchCenter - 30,

      45,

      notchCenter,

      45,

    );


    path.cubicTo(

      notchCenter + 30,

      45,

      notchCenter + 20,

      0,

      notchCenter + 45,

      0,

    );


    path.lineTo(
      width,
      0,
    );


    path.lineTo(
      width,
      height,
    );


    path.lineTo(
      0,
      height,
    );


    path.close();


    return path;
  }


  @override
  bool shouldReclip(
      covariant CustomClipper<Path> oldClipper,
      ) =>
      true;
}
