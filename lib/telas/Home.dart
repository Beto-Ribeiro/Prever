import 'package:branch1/telas/cadastro_tela.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'exportador_import.dart';
import 'tela_sobrevivencia.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../controles/controle_acessibilidade.dart';

class Home extends StatefulWidget {
  final Function(int) onChangePage;
  const Home({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<Home> createState() => _Home_State();
}

Future<void> _Ask_for_permission() async {
  PermissionStatus status = await Permission.location.request();

  if (status.isGranted) {
    Position position = await Geolocator.getCurrentPosition();
  } else if (status.isDenied || status.isPermanentlyDenied) {
    debugPrint('Permissão de localização negada pelo usuário.');
  }
}

Future<void> Criar_SOS(
  BuildContext context, {
  required String usuarioId,
  required String localizacao,
  required String data,
  required String origem,
}) async {
  final supabase = Supabase.instance.client;

  await _Ask_for_permission();

  Position posicao = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
    ),
  );

  final String pontoGeografico =
      'POINT(${posicao.longitude} ${posicao.latitude})';

  try {
    await supabase.from('Relato').insert({
      'rel_cid_id': usuarioId,
      'rel_tipo_desastre': "SOS",
      'rel_descricao': "Auxílio",
      'rel_localizacao': localizacao,
      'rel_data_hora': data,
    });
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Erro'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}


//Message box para avisar que o relato foi enviado, ficou redundante.
//void mostrarRelatoEnviado(BuildContext context) {
//  showDialog(
//    context: context,
//    builder: (context) => AlertDialog(
//      title: const Text('Sucesso'),
//      content: const Text(
//        'Ocorrência reportada com sucesso. As autoridades estão a caminho.',
//      ),
//      actions: [
//        TextButton(
//          onPressed: () {
//            Navigator.pop(context);
//          },
//          child: const Text('OK'),
//        ),
//      ],
//    ),
//  );
//}

class _Home_State extends State<Home> {
  bool _sosEnviado = false;
  bool _sosEnviando = false;


  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                // Expanded é essencial aqui: ele diz ao
                // SingleChildScrollView exatamente quanto espaço vertical
                // está disponível. Sem isso, quando o conteúdo cresce
                // (letras grandes), ele extravasa por baixo da tela em
                // vez de rolar — foi essa a causa do "BOTTOM OVERFLOWED".
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      child: Column(
                        children: [
                          // Reserva o espaço do avatar
                          // (ContainerPerfilSuperior tem height: 100) para
                          // o título nunca ficar atrás dele, mesmo com
                          // letras grandes.
                          const SizedBox(height: 100),

                          // ── Título principal animado ──────────────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 500),
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, -0.2),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: _sosEnviado
                                ? Container(
                                    key: const ValueKey('enviado'),
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      "Auxílio solicitado!",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: acessibilidade.corPrimaria,
                                      ),
                                    ),
                                  )
                                : _sosEnviando?
                            Column(
                              key: const ValueKey('enviando'),
                              children: [
                                Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    "Enviando SOS para" ,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: acessibilidade.corPrimaria,
                                    ),
                                  ),
                                ),
                                Container(
                                  width: double.infinity,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    "as autoridades",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      color: acessibilidade.corPrimaria,
                                    ),
                                  ),
                                ),
                              ],
                            ):
                            Column(
                                    key: const ValueKey('inicial'),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          "Precisa de ajuda de" ,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: acessibilidade.corPrimaria,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          "emergência?",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 34,
                                            fontWeight: FontWeight.bold,
                                            color: acessibilidade.corPrimaria,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),

                          // ── Subtítulo animado ──────────────────────────
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: _sosEnviado
                                ? Container(
                                    key: const ValueKey('subEnviado'),
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      "As autoridades estão a caminho",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: acessibilidade.corSecundaria,
                                      ),
                                    ),
                                  )
                                : _sosEnviando?
                                  Container(
                                    key: const ValueKey('subEnviando'),
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      "Por favor, aguarde alguns instantes.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: acessibilidade.corSecundaria,
                                      ),
                                    ),
                                  )
                                : Container(
                                    key: const ValueKey('subInicial'),
                                    width: double.infinity,
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                    ),
                                    child: Text(
                                      "Pressione o botão abaixo para acioná-la",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: acessibilidade.corSecundaria,
                                      ),
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 20),

                          // ── Botão SOS ───────────────────────────────────
                          AbsorbPointer(
                            absorbing: _sosEnviado,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(150),
                              onTap: _sosEnviado
                                  ? null
                                  : () async {

                                      setState(() {
                                        _sosEnviando = true;
                                      });

                                      Position posicao =
                                          await Geolocator.getCurrentPosition(
                                            locationSettings:
                                                const LocationSettings(
                                                  accuracy:
                                                      LocationAccuracy.high,
                                                ),
                                          );

                                      final String pontoGeografico =
                                          'POINT(${posicao.longitude} ${posicao.latitude})';

                                      await Criar_SOS(
                                        context,
                                        usuarioId: Supabase
                                            .instance
                                            .client
                                            .auth
                                            .currentUser!
                                            .id,
                                        localizacao: pontoGeografico,
                                        data: DateTime.now().toIso8601String(),
                                        origem: 'SOS',
                                      );

                                      // Atualiza estado para animar e
                                      // desabilitar
                                      setState(() {
                                        _sosEnviado = true;
                                        _sosEnviando = false;
                                      });
                                    },
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedPositioned(
                                    duration: Duration(seconds: 2),
                                    curve: ElasticOutCurve(0.6),
                                      left: _sosEnviado? -25: 100,
                                      bottom: _sosEnviado? -25: 100,
                                      child: AnimatedContainer(
                                        duration: Duration(seconds: 1),
                                              curve: Curves.easeInOut,
                                              width: 70,
                                              height: 70,
                                        decoration: BoxDecoration(
                                          image: DecorationImage(image: AssetImage("gfx/png/Image/chamadas.png")),
                                          color: _sosEnviado
                                              ? const Color.fromRGBO(
                                            80,
                                            80,
                                            80,
                                            0.4,
                                          ) : _sosEnviando?
                                          Colors.orangeAccent
                                              : acessibilidade.daltonismo
                                              ? const Color(
                                            0xFFF4A261,
                                          ).withValues(alpha: 0.5)
                                              : const Color.fromRGBO(
                                            200,
                                            0,
                                            0,
                                            0.5,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),

                                  ),
                                  // Anel externo — vermelho ou laranja (daltonismo)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeInOut,
                                    width: 300,
                                    height: 300,
                                    decoration: BoxDecoration(
                                      color: _sosEnviado
                                          ? const Color.fromRGBO(
                                              80,
                                              80,
                                              80,
                                              0.4,
                                            ) : _sosEnviando?
                                          Colors.orangeAccent
                                          : acessibilidade.daltonismo
                                          ? const Color(
                                              0xFFF4A261,
                                            ).withValues(alpha: 0.5)
                                          : const Color.fromRGBO(
                                              200,
                                              0,
                                              0,
                                              0.5,
                                            ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  // Círculo interno — vermelho ou laranja (daltonismo)
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 600),
                                    curve: Curves.easeInOut,
                                    width: 275,
                                    height: 275,
                                    decoration: BoxDecoration(
                                      color: _sosEnviado
                                          ? const Color.fromRGBO(
                                              100,
                                              100,
                                              100,
                                              1,
                                            ): _sosEnviando?
                                      Colors.orange
                                          : acessibilidade.daltonismo
                                          ? const Color(0xFFF4A261)
                                          : const Color.fromRGBO(225, 0, 0, 1),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SvgPicture.asset(
                                    'gfx/svg/icons/btn_alert.svg',
                                    width: 225,
                                    colorFilter: _sosEnviado
                                        ? const ColorFilter.mode(
                                            Color.fromRGBO(180, 180, 180, 1),
                                            BlendMode.srcIn,
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // BOTÃO DO GUIA DE SOBREVIVÊNCIA
                          const SizedBox(height: 40),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 30),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => TelaSobrevivencia(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  backgroundColor: acessibilidade.corPrimaria,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  'Acesse o Guia de Sobrevivência',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 90,
                            width: double.infinity,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

          ],
        ),
      ),
    );
  }
}
