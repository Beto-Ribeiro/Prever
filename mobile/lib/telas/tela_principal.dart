import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:prever/services/alertas_notificacao_service.dart';
import 'package:prever/services/relatos_proximos_service.dart';
import 'exportador_import.dart';

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
  late final Set<int> _telasVisitadas;
  int _solicitacaoRelato = 0;

  void _abrirRelatoNoMapa(RelatoProximo relato) {
    setState(() {
      _telas[1] = Maps_alertas(
        title: 'Mapa de alertas',
        onChangePage: changePage,
        relatoSelecionado: relato,
        solicitacaoRelato: ++_solicitacaoRelato,
      );
      _telasVisitadas.add(1);
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
    Icons.home_outlined,
  ];

  // ==========================================================================
  // INIT STATE
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _currentIndex = supabase.auth.currentUser == null ? 6 : 0;
    _telasVisitadas = <int>{_currentIndex};

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

    _pedirPermissao();
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

    _authSubscription = supabase.auth.onAuthStateChange.listen(
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
            _telasVisitadas.add(12);
            _currentIndex = 12;
          });

          return;
        }

        // ====================================================================
        // SESSÃO ENCERRADA
        // ====================================================================

        if (data.event == AuthChangeEvent.signedOut) {
          setState(() {
            nome = '';
            tipoUsuario = '';
            estalogado = false;
            senhaCadastro = null;
          });
          return;
        }

        // ====================================================================
        // EXISTE UMA SESSÃO (LOGIN DIRETO, OAUTH GOOGLE OU DEEP LINK DE E-MAIL)
        // ====================================================================

        if (data.session != null) {
          if (data.event == AuthChangeEvent.signedIn) {
            setState(() {
              estalogado = true;
              senhaCadastro = null;
              // Redireciona para a Home quando o retorno de OAuth/confirmação
              // ocorre a partir das telas de entrada/cadastro/confirmação.
              if (_currentIndex >= 5 && _currentIndex <= 8) {
                _telasVisitadas.add(0);
                _currentIndex = 0;
              }
            });
          }

          // Evita ficar consultando o perfil desnecessariamente
          // em eventos como tokenRefreshed.
          if (data.event == AuthChangeEvent.initialSession ||
              data.event == AuthChangeEvent.signedIn ||
              data.event == AuthChangeEvent.userUpdated) {
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
      final currentUser = supabase.auth.currentUser;
      final userId = currentUser?.id;

      // ----------------------------------------------------------------------
      // USUÁRIO NÃO ENCONTRADO
      // ----------------------------------------------------------------------

      if (userId == null) {
        if (mounted) {
          setState(() {
            carregando = false;
          });
        }

        return;
      }

      final metadata = currentUser?.userMetadata ?? const <String, dynamic>{};
      final fallbackNome =
          (metadata['prf_nome'] ??
                  metadata['full_name'] ??
                  metadata['name'] ??
                  currentUser?.email?.split('@').first ??
                  '')
              .toString()
              .trim();

      // ======================================================================
      // PERFIL + VÍNCULO DE CIDADÃO (INCLUINDO LOGIN GOOGLE OAUTH)
      // ======================================================================

      try {
        Map<String, dynamic>? perfil = await supabase
            .from('Perfis')
            .select()
            .eq(
              'prf_id',
              userId,
            )
            .maybeSingle();

        if (perfil == null) {
          try {
            await supabase.from('Perfis').insert({
              'prf_id': userId,
              'prf_nome': fallbackNome.isEmpty ? 'Cidadão' : fallbackNome,
              'prf_tipo': 'cidadao',
              'prf_permissoes': <String, dynamic>{},
            });
            perfil = {
              'prf_id': userId,
              'prf_nome': fallbackNome.isEmpty ? 'Cidadão' : fallbackNome,
              'prf_tipo': 'cidadao',
            };
          } catch (_) {
            // Ignora conflito concorrente com trigger ou política RLS.
          }
        }

        // Garante registro em Cidadao para usuários OAuth poderem enviar relatos
        // e registrar histórico médico sem erro de chave estrangeira.
        final tipoAtual = (perfil?['prf_tipo'] ?? 'cidadao')
            .toString()
            .toLowerCase();
        if (tipoAtual == 'cidadao' ||
            tipoAtual == 'cidadão' ||
            tipoAtual == 'pendente') {
          try {
            final cidadaoExistente = await supabase
                .from('Cidadao')
                .select('cid_id')
                .eq('cid_id', userId)
                .maybeSingle();
            if (cidadaoExistente == null) {
              await supabase.from('Cidadao').insert({'cid_id': userId});
            }
          } catch (_) {
            // Segue normalmente se o registro já existir ou RLS restringir.
          }
        }

        if (!mounted) {
          return;
        }

        final nomeResolvido = (perfil?['prf_nome'] ?? '').toString().trim();

        setState(() {
          nome = nomeResolvido.isNotEmpty ? nomeResolvido : fallbackNome;
          tipoUsuario = (perfil?['prf_tipo'] ?? 'cidadao').toString();
          estalogado = true;
          carregando = false;
        });
      } catch (e) {
        debugPrint(
          'Erro ao consultar perfil: $e',
        );

        if (mounted) {
          setState(() {
            if (nome.isEmpty && fallbackNome.isNotEmpty) {
              nome = fallbackNome;
            }
            carregando = false;
          });
        }
      }
    } catch (e) {
      debugPrint(
        'Erro ao carregar dados: $e',
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
      ClimaTela(
        onChangePage: changePage,
      ),

      // ======================================================================
      // 4 - ABRIGOS
      // ======================================================================
      AbrigosTela(
        title: 'Abrigos',
        onChangePage: changePage,
      ),

      // ======================================================================
      // 5 - CADASTRO
      // ======================================================================
      Cadastro_tela(
        title: "Cadastro",

        onChangePage: changePage,

        onCadastroPendente: (email, senha) {
          setState(() {
            emailCadastro = email;

            senhaCadastro = senha;

            _telasVisitadas.add(7);
            _currentIndex = 7;

            _telas[7] = ConfEmail(
              title: "Confirmação",

              onChangePage: changePage,

              email: emailCadastro,

              senha: senhaCadastro,
            );
          });
        },
      ),

      // ======================================================================
      // 6 - LANDING PAGE LOGIN/CADASTRO
      // ======================================================================
      SLogCad(
        title: "Landing Page",
        onChangePage: changePage,
      ),

      // ======================================================================
      // 7 - CONFIRMAÇÃO DE E-MAIL
      // ======================================================================
      ConfEmail(
        title: "Confirmação",

        onChangePage: changePage,

        email: emailCadastro,

        senha: senhaCadastro,
      ),

      // ======================================================================
      // 8 - LOGIN
      // ======================================================================
      SLogin(
        title: "Login",
        onChangePage: changePage,
      ),

      // ======================================================================
      // 9 - PERFIL
      // ======================================================================
      TelaPerfil(
        title: "Perfil",
        onChangePage: changePage,
      ),

      // ======================================================================
      // 10 - NIMBO
      // ======================================================================
      ChatbotTela(
        title: 'Nimbo',
        onChangePage: changePage,
      ),

      // ======================================================================
      // 11 - SOLICITAR REDEFINIÇÃO DE SENHA
      // ======================================================================
      ChangePassword(
        title: 'Change Password',
        onChangePage: changePage,
      ),

      // ======================================================================
      // 12 - ESCREVER A NOVA SENHA
      // ======================================================================
      WriteChangedPassword(
        onChangePage: changePage,
      ),

      //=======================================================================
      //13 - EDITAR PERFIL
      EditarPerfilTela(title: 'editar', onChangePage: changePage),
    ];
  }

  // ==========================================================================
  // PERMISSÃO DE LOCALIZAÇÃO E ALERTAS PUSH
  // ==========================================================================

  Future<void> _pedirPermissao() async {
    try {
      final permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (_) {
      debugPrint('Localização indisponível neste dispositivo.');
    }
    if (!mounted) return;
    await AlertasNotificacaoService.instance.iniciar(
      abrirMapa: () {
        if (mounted) changePage(1);
      },
    );
  }

  // ==========================================================================
  // TROCA DE PÁGINA
  // ==========================================================================

  void changePage(int index) {
    if (!mounted) {
      return;
    }

    // Proteção contra índices inválidos
    if (index < 0 || index >= _telas.length) {
      debugPrint(
        'Índice de tela inválido: $index',
      );

      return;
    }

    setState(() {
      _telasVisitadas.add(index);
      _currentIndex = index;

      // O IndexedStack preserva o estado: recarrega os dados ao abrir o perfil.
      if (index == 9) {
        _telas[9] = TelaPerfil(
          key: UniqueKey(),
          title: 'Perfil',
          onChangePage: changePage,
        );
      } else if (index == 13) {
        _telas[13] = EditarPerfilTela(
          key: UniqueKey(),
          title: 'Editar perfil',
          onChangePage: changePage,
        );
      }
    });
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _authSubscription?.cancel();
    unawaited(AlertasNotificacaoService.instance.dispose());

    _nimboAnimController.dispose();

    super.dispose();
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final bool ocultarNav = _currentIndex >= 5;

    final bool noNimbo = _currentIndex == 10;

    return Scaffold(
      extendBody: true,

      // ======================================================================
      // BODY
      // ======================================================================
      body: Stack(
        children: [
          // ==================================================================
          // CONTEÚDO PRINCIPAL (MONTAGEM LAZY SOB DEMANDA)
          // ==================================================================
          Padding(
            padding: ocultarNav
                ? const EdgeInsets.only(top: 0)
                : _currentIndex == 0
                ? const EdgeInsets.only(top: 0)
                : const EdgeInsets.only(top: 30),

            child: IndexedStack(
              index: _currentIndex,

              children: List<Widget>.generate(_telas.length, (i) {
                if (!_telasVisitadas.contains(i)) {
                  return const SizedBox.shrink();
                }
                if (i == 0) {
                  return Home(
                    title: 'SOS',
                    onChangePage: changePage,
                    onAbrirRelato: _abrirRelatoNoMapa,
                    ativa: _currentIndex == 0,
                  );
                }
                return _telas[i];
              }),
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

                    changePage(10);
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
                      color: Color(
                        0xFF0B1426,
                      ),

                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),

                        topRight: Radius.circular(32),

                        bottomLeft: Radius.circular(32),

                        bottomRight: Radius.circular(4),
                      ),

                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.15,
                        ),

                        width: 2,
                      ),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.35,
                          ),

                          blurRadius: 12,

                          offset: const Offset(
                            0,
                            4,
                          ),
                        ),
                      ],
                    ),

                    child: Padding(
                      padding: EdgeInsets.all(
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
      bottomNavigationBar: ocultarNav || noNimbo
          ? null
          : CustomAnimatedBottomBar(
              currentIndex: _currentIndex,

              icones: _icones,

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

class CustomAnimatedBottomBar extends StatelessWidget {
  final int currentIndex;

  final List<IconData> icones;

  final Function(int) onTap;

  const CustomAnimatedBottomBar({
    super.key,

    required this.currentIndex,

    required this.icones,

    required this.onTap,
  });

  final Color corFundoMenu = const Color(
    0xFF0B1426,
  );

  final Color corIconeInativo = const Color(
    0xFF4A5568,
  );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,

      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: currentIndex.toDouble(),

          end: currentIndex.toDouble(),
        ),

        duration: const Duration(
          milliseconds: 350,
        ),

        curve: Curves.easeInOutBack,

        builder:
            (
              context,
              value,
              child,
            ) {
              final double segmentWidth =
                  MediaQuery.of(context).size.width / icones.length;

              final double buttonLeftOffset =
                  (segmentWidth * value) + (segmentWidth / 2) - 28;

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

                        color: corFundoMenu,

                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,

                          children: List.generate(
                            icones.length,

                            (index) {
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,

                                onTap: () {
                                  onTap(
                                    index,
                                  );
                                },

                                child: SizedBox(
                                  width: segmentWidth,

                                  height: 70,

                                  child: Icon(
                                    icones[index],

                                    color: currentIndex == index
                                        ? Colors.transparent
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

                    left: buttonLeftOffset,

                    child: GestureDetector(
                      onTap: () {
                        onTap(
                          currentIndex,
                        );
                      },

                      child: Container(
                        width: 56,

                        height: 56,

                        decoration: BoxDecoration(
                          color: corFundoMenu,

                          shape: BoxShape.circle,

                          border: Border.all(
                            color: Colors.white,

                            width: 3.5,
                          ),
                        ),

                        child: Icon(
                          icones[currentIndex < icones.length
                              ? currentIndex
                              : 0],

                          color: Colors.white,

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

class MenuClipper extends CustomClipper<Path> {
  final double position;

  final int segments;

  MenuClipper(
    this.position,
    this.segments,
  );

  @override
  Path getClip(Size size) {
    final path = Path();

    final double width = size.width;

    final double height = size.height;

    final double segmentWidth = width / segments;

    final double notchCenter = (segmentWidth * position) + (segmentWidth / 2);

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
  ) => true;
}
