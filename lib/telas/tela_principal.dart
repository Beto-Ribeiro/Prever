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

  final supabase = Supabase.instance.client;
  String nome = '';
  bool carregando = true;
  String tipoUsuario = '';

  Future<void> _esperarSessaoECarregar() async {
    // Se já tem usuário, carrega direto
    if (supabase.auth.currentUser != null) {
      carregarDados();
      return;
    }

    // Aguarda o evento de sessão restaurada
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        carregarDados();
      }
    });
  }


  Future<void> carregarDados() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      print('=== USER ID: $userId ===');
      if (userId == null) {
        print('=== USUÁRIO NULO ===');
        setState(
              () => carregando = false,
        ); // <-- não esquece de parar o loading
        return;
      }

      // ── PERFIL ────────────────────────────────────────────────────────────
      try {
        final perfil = await supabase
            .from('Perfis')
            .select()
            .eq('prf_id', userId)
            .limit(1)
            .single();
        print('=== PERFIL OK: $perfil ===');
        setState(() {
          nome = perfil['prf_nome'] ?? '';
          tipoUsuario = perfil['prf_tipo'] ?? '';
        });
      } catch (e) {
        print('=== ERRO PERFIL: $e ===');
      }
  } catch (e) {
      print('=== ERRO PERFIL: $e ===');
    }
  }


  // ── Variáveis de estado ───────────────────────────────────────────────────
  late List<Widget> _telas;

  bool estalogado = false;

  late int _currentIndex;

  String? emailCadastro;
  String? senhaCadastro;

  // ── Animação do botão Nimbo ───────────────────────────────────────────────
  late final AnimationController _nimboAnimController;
  late final Animation<double> _nimboScaleAnim;

  final List<IconData> _icones = [
    Icons.warning_amber_rounded,
    Icons.location_on_outlined,
    Icons.flag_outlined,
    Icons.cloud_queue,
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _esperarSessaoECarregar();
    _currentIndex = Supabase.instance.client.auth.currentUser == null ? 5 : 0;

    // Animação do botão Nimbo
    _nimboAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.88,
      upperBound: 1.0,
    )..value = 1.0;
    _nimboScaleAnim = _nimboAnimController;

    _Ask_for_permission();
    _inicializarTelas(); // cria as telas UMA VEZ SÓ
  }

  @override
  void dispose() {
    _nimboAnimController.dispose();
    super.dispose();
  }

  // ── Inicializa a lista de telas ───────────────────────────────────────────
  void _inicializarTelas() {
    _telas = [
      Home(title: "SOS", onChangePage: changePage), // 0
      Maps_alertas(title: "SOS", onChangePage: changePage), // 1
      Relatos_tela(title: "Relato", onChangePage: changePage), // 2
      ClimaTela(onChangePage: changePage), // 3
      Cadastro_tela(
        // 4
        title: "Cadastro",
        onChangePage: changePage,
        onCadastroPendente: (email, senha) {
          print("RECEBI EMAIL NA TELA PRINCIPAL: $email");
          print("RECEBI SENHA NA TELA PRINCIPAL: $senha");
          setState(() {
            emailCadastro = email;
            senhaCadastro = senha;
            _currentIndex = 6;
            // Recria só o índice 6 com os dados que chegaram agora
            _telas[6] = confEmail(
              title: "Confirmação",
              onChangePage: changePage,
              email: emailCadastro,
              senha: senhaCadastro,
            );
          });
        },
      ),
      sLogCad(title: "Landing Page", onChangePage: changePage), // 5
      confEmail(
        // 6
        title: "Confirmação",
        onChangePage: changePage,
        email: emailCadastro,
        senha: senhaCadastro,
      ),
      sLogin(title: "Login", onChangePage: changePage), // 7
      TelaPerfil(title: "Perfil", onChangePage: changePage), // 8
      ChatbotTela(title: 'Nimbo', onChangePage: changePage), // 9 — IA Chatbot
    ];
  }

  // ── Permissão de localização ──────────────────────────────────────────────
  Future<void> _Ask_for_permission() async {
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      Position position = await Geolocator.getCurrentPosition();
    } else if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('Permissão de localização negada pelo usuário.');
    }
  }

  // ── Troca de página ───────────────────────────────────────────────────────
  void changePage(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Telas que ocultam nav bar E o botão Nimbo
    final bool ocultarNav =
        (_currentIndex == 4 ||
        _currentIndex == 5 ||
        _currentIndex == 6 ||
        _currentIndex == 7 ||
        _currentIndex == 8);
    final bool noNimbo = _currentIndex == 9; // já está no chatbot

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // ── Conteúdo principal ────────────────────────────────────────────
          Padding(
            padding: ocultarNav? const EdgeInsets.only(top: 0) : _currentIndex == 0? const EdgeInsets.only(top: 0) : const EdgeInsets.only(top: 30) ,
            child: IndexedStack(
              index: _currentIndex,
              children: _telas,
            ),
          ),

          // ── Botão flutuante Nimbo ─────────────────────────────────────────
          // Aparece apenas nas telas com nav bar e quando não estamos no chatbot
          if (!ocultarNav && !noNimbo)
            Positioned(
              bottom: 80, // logo acima da nav bar (altura 70)
              right: 20,
              child: ScaleTransition(
                scale: _nimboScaleAnim,
                child: GestureDetector(
                  onTapDown: (_) => _nimboAnimController.reverse(),
                  onTapUp: (_) {
                    _nimboAnimController.forward();
                    setState(() => _currentIndex = 9);
                  },
                  onTapCancel: () => _nimboAnimController.forward(),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1426),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                        bottomLeft: Radius.circular(32),
                        bottomRight: Radius.circular(4),
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'gfx/png/Image/nimbo_icon.png',
                        fit: BoxFit.contain,
                        isAntiAlias: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),ocultarNav ? Container() : SafeArea(
              child: ContainerPerfilSuperior(
                onChangePage: changePage, nome: nome,
              ),
          ),

        ],
      ),
      bottomNavigationBar: ocultarNav || noNimbo
          ? null
          : CustomAnimatedBottomBar(
              currentIndex: _currentIndex,
              icones: _icones,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
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

  final Color corFundoMenu = const Color(0xFF0B1426);
  final Color corIconeInativo = const Color(0xFF4A5568);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          begin: currentIndex.toDouble(),
          end: currentIndex.toDouble(),
        ),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutBack,
        builder: (context, value, child) {
          final double segmentWidth =
              MediaQuery.of(context).size.width / icones.length;
          final double buttonLeftOffset =
              (segmentWidth * value) + (segmentWidth / 2) - 28;

          return Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipPath(
                  clipper: MenuClipper(value, icones.length),
                  child: Container(
                    height: 70,
                    color: corFundoMenu,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(icones.length, (index) {
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(index),
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
                      }),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: buttonLeftOffset,
                child: GestureDetector(
                  onTap: () => onTap(currentIndex),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: corFundoMenu,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5),
                    ),
                    child: Icon(
                      icones[currentIndex],
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

  MenuClipper(this.position, this.segments);

  @override
  Path getClip(Size size) {
    final path = Path();
    final double width = size.width;
    final double height = size.height;

    final double segmentWidth = width / segments;
    final double notchCenter = (segmentWidth * position) + (segmentWidth / 2);

    path.lineTo(notchCenter - 45, 0);
    path.cubicTo(notchCenter - 20, 0, notchCenter - 30, 45, notchCenter, 45);
    path.cubicTo(
      notchCenter + 30,
      45,
      notchCenter + 20,
      0,
      notchCenter + 45,
      0,
    );
    path.lineTo(width, 0);
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}
