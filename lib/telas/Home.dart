import 'package:prever/telas/cadastro_tela.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'exportador_import.dart';
import 'tela_sobrevivencia.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../controles/controle_acessibilidade.dart';
import 'package:prever/telas/widgets/relatos_proximos.dart';
import 'package:prever/services/relatos_proximos_service.dart';

class Home extends StatefulWidget {
  final bool ativa;
  final ValueChanged<RelatoProximo>? onAbrirRelato;
  final Function(int) onChangePage;
  const Home({
    super.key,
    required this.title,
    required this.onChangePage,
    this.ativa = true,
    this.onAbrirRelato,
  });

  final String title;

  @override
  State<Home> createState() => _Home_State();
}



Future<void> Criar_SOS({
  required String usuarioId,
  required String localizacao,
  required String data,
}) async {
  final supabase = Supabase.instance.client;

  await supabase.from('Relato').insert({
    'rel_cid_id': usuarioId,
    'rel_tipo_desastre': "SOS",
    'rel_descricao': "Auxílio",
    'rel_localizacao': localizacao,
    'rel_data_hora': data,
  });
}

//Message box para avisar que o relato foi enviado, ficou redundante.

class _Home_State extends State<Home> {
  bool _sosEnviado = false;
  bool _sosEnviando = false;

  final _SOSvalidateController = TextEditingController();

  final supabase = Supabase.instance.client;

  Future<String?> _validarCpf(String cpfDigitado, String userId) async {
    if (!RegExp(r'^[0-9]{3}$').hasMatch(cpfDigitado)) {
      return 'Digite os três primeiros dígitos do CPF.';
    }
    final data = await supabase
        .from('Cidadao')
        .select('cid_cpf')
        .eq('cid_id', userId)
        .maybeSingle();
    final cpfCompleto = data?['cid_cpf']?.toString() ?? '';
    final cpfLimpo = cpfCompleto.replaceAll(RegExp(r'[^0-9]'), '');
    if (cpfLimpo.length != 11) {
      return 'CPF indisponível no cadastro.';
    }
    if (!cpfLimpo.startsWith(cpfDigitado)) {
      return 'Os dígitos não conferem com o CPF cadastrado.';
    }
    return null;
  }

  @override
  void dispose() {
    _SOSvalidateController.dispose();
    super.dispose();
  }

  Future<void> ValidacaoIdentidade(BuildContext context) async {
    _SOSvalidateController.clear();
    String? erroCpf;
    bool validando = false;
    final usuarioId = await showDialog<String>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, atualizarDialogo) => Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 25),
              width: 350,
              constraints: const BoxConstraints(minHeight: 300),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      InkWell(
                        child: Icon(Icons.close),
                        onTap: () {
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        const TextSpan(text: "Insira os "),

                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red[900],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "TRÊS PRIMEIROS",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const TextSpan(text: " seu CPF"),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    "Precisamos confirmar sua identidade para emitir um alerta SOS",
                    style: TextStyle(fontSize: 12, color: Colors.black),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 25),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      textAlign: TextAlign.center,
                      textAlignVertical: TextAlignVertical.center,
                      controller: _SOSvalidateController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 3,
                      maxLines: 1,
                      enabled: !validando,
                      onChanged: (_) {
                        if (erroCpf != null) {
                          atualizarDialogo(() => erroCpf = null);
                        }
                      },
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.zero,
                        hintText: 'CPF...',
                        errorText: erroCpf,
                        errorMaxLines: 3,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[900],
                        ),
                        onPressed: validando
                            ? null
                            : () async {
                                if (validando) return;
                                final userId = supabase.auth.currentUser?.id;
                                if (userId == null) {
                                  atualizarDialogo(
                                    () => erroCpf =
                                        'Entre na sua conta para enviar o SOS.',
                                  );
                                  return;
                                }
                                atualizarDialogo(() {
                                  validando = true;
                                  erroCpf = null;
                                });
                                String? erro;
                                try {
                                  erro = await _validarCpf(
                                    _SOSvalidateController.text,
                                    userId,
                                  );
                                } catch (_) {
                                  erro =
                                      'Não foi possível consultar o CPF. Tente novamente.';
                                }
                                if (!context.mounted ||
                                    ModalRoute.of(context)?.isCurrent != true) {
                                  return;
                                }
                                if (erro == null) {
                                  Navigator.pop(context, userId);
                                  return;
                                }
                                atualizarDialogo(() {
                                  validando = false;
                                  erroCpf = erro;
                                });
                              },
                        child: Text(
                          "Enviar",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted || usuarioId == null || _sosEnviando || _sosEnviado) return;

    setState(() => _sosEnviando = true);
    try {
      final posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      await Criar_SOS(
        usuarioId: usuarioId,
        localizacao: 'POINT(${posicao.longitude} ${posicao.latitude})',
        data: DateTime.now().toIso8601String(),
      );
      if (mounted) setState(() => _sosEnviado = true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível enviar o SOS. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sosEnviando = false);
    }
  }

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
                                : _sosEnviando
                                ? Column(
                                    key: const ValueKey('enviando'),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          "Enviando SOS para",
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
                                  )
                                : Column(
                                    key: const ValueKey('inicial'),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          "Precisa de ajuda de",
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
                                : _sosEnviando
                                ? Container(
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
                              onTap: _sosEnviado || _sosEnviando
                                  ? null
                                  : () => ValidacaoIdentidade(context),
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  AnimatedPositioned(
                                    duration: Duration(seconds: 2),
                                    curve: ElasticOutCurve(0.6),
                                    left: _sosEnviado ? -25 : 100,
                                    bottom: _sosEnviado ? -25 : 100,
                                    child: AnimatedContainer(
                                      duration: Duration(seconds: 1),
                                      curve: Curves.easeInOut,
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        image: DecorationImage(
                                          image: AssetImage(
                                            "gfx/png/Image/chamadas.png",
                                          ),
                                        ),
                                        color: _sosEnviado
                                            ? const Color.fromRGBO(
                                                80,
                                                80,
                                                80,
                                                0.4,
                                              )
                                            : _sosEnviando
                                            ? Colors.orangeAccent
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
                                            )
                                          : _sosEnviando
                                          ? Colors.orangeAccent
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
                                            )
                                          : _sosEnviando
                                          ? Colors.orange
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
                                onPressed: () async {
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
                          SizedBox(
                            height: 45,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                            child: RelatosProximos(ativa: widget.ativa,
                              onAbrirRelato: widget.onAbrirRelato),
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
