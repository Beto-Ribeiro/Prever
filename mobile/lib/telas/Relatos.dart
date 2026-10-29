import 'package:prever/telas/exportador_import.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../controles/controle_acessibilidade.dart';
import '../services/antifraude_service.dart';
import 'widgets/dialogo_antifraude.dart';

class Relatos_tela extends StatefulWidget {
  final Function(int) onChangePage;
  const Relatos_tela({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<Relatos_tela> createState() => _Relatos_telaState();
}

class _Relatos_telaState extends State<Relatos_tela> {
  PlatformFile? imagemSelecionada;
  Uint8List? imagemBytes;

  int? tipoSelecionado;
  int? nivelSelecionado;

  // Campo de descrição textual livre
  final TextEditingController _descricaoController = TextEditingController();

  // Controle de estado do filtro antifraude
  final AntiFraudeService _antiFraudeService = AntiFraudeService();

  // Variáveis para o Mapa e Localização
  GoogleMapController? mapController;

  LatLng? localizacaoSelecionada;
  Set<Marker> markers = {};
  bool _isLoadingMap = true;
  bool _utilizarLocalizacaoAtual = true;
  ScrollPhysics _scrollPhysics = const ClampingScrollPhysics();

  // Rótulos e cores usados no seletor de severidade (Leve / Moderada / Severa)
  final List<String> _opcoesSeveridade = const ['Leve', 'Moderada', 'Severa'];
  final List<Color> _coresSeveridade = [
    Colors.amber.shade600,
    Colors.orange.shade700,
    Colors.red.shade700,
  ];

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _antiFraudeService.dispose();
    super.dispose();
  }

  // Verifica permissões de localização
  Future<void> _checkLocationPermission() async {
    var status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() => _isLoadingMap = false);
    }
  }

  // Pega a localização atual do celular
  Future<void> _getCurrentLocation() async {
    try {
      Position locationData = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      LatLng posicaoAtual = LatLng(
        locationData.latitude,
        locationData.longitude,
      );

      setState(() {
        localizacaoSelecionada = posicaoAtual;
        _isLoadingMap = false;
        _atualizarMarcador(posicaoAtual);
      });

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(posicaoAtual, 16),
        );
      }
    } catch (e) {
      debugPrint("Erro ao obter localização: $e");
      setState(() => _isLoadingMap = false);
    }
  }

  // Atualiza o marcador visual no mapa
  void _atualizarMarcador(LatLng posicao) {
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId('selecionado'),
          position: posicao,
        ),
      );
    });
  }

  // Selecionar imagem da galeria
  Future<void> selecionarImagem() async {
    FilePickerResult? resultado = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (resultado != null) {
      setState(() {
        imagemSelecionada = resultado.files.single;
        imagemBytes = resultado.files.single.bytes;
      });
    }
  }

  // Texto descritivo exibido conforme o tipo de desastre selecionado
  String _descricaoTipo(int? tipo) {
    switch (tipo) {
      case 0:
        return 'Água acumulada nas ruas, casas alagadas ou rios transbordando.';
      case 1:
        return 'Ventos fortes, destruição de estruturas e risco de queda de árvores.';
      case 2:
        return 'Barrancos caindo, terra ou rochas deslizando em encostas, rachaduras grandes no solo ou muros estufados.';
      case 3:
        return 'Chuva intensa e contínua, risco de alagamentos e deslizamentos.';
      default:
        return '';
    }
  }

  // ── Helpers de mapeamento ────────────────────────────────────────────────

  String _mapearTipoDesastre(int? tipo) {
    switch (tipo) {
      case 0:
        return 'Alagamento';
      case 1:
        return 'Tornado';
      case 2:
        return 'Desabamento';
      case 3:
        return 'Chuva Forte';
      default:
        return 'Desconhecido';
    }
  }

  String _mapearNivelRisco(int? nivel) {
    switch (nivel) {
      case 0:
        return 'Leve';
      case 1:
        return 'Moderada';
      case 2:
        return 'Severa';
      default:
        return 'Desconhecida';
    }
  }

  // ── Validação dos campos antes de enviar ─────────────────────────────────

  bool _validarCampos() {
    if (tipoSelecionado == null ||
        nivelSelecionado == null ||
        imagemSelecionada == null ||
        imagemBytes == null ||
        localizacaoSelecionada == null) {
      _mostrarSnackBar(
        'Preencha todos os campos e selecione a localização no mapa.',
        Colors.orange,
      );
      return false;
    }
    return true;
  }

  // ── Grava o relato no Supabase com os metadados antifraude ───────────────

  Future<void> _gravarNoSupabase({
    required String tipoDesastre,
    required String nivelRisco,
    required String descricao,
    required String userId,
    required String pontoGeografico,
    required ResultadoAntifraude resultadoAntifraude,
  }) async {
    final supabase = Supabase.instance.client;

    final List<Map<String, dynamic>> respostaRelato = await supabase
        .from('Relato')
        .insert({
          'rel_tipo_desastre': tipoDesastre,
          'rel_gravidade': nivelRisco,
          'rel_descricao': descricao,
          'rel_cid_id': userId,
          'rel_localizacao': pontoGeografico,
          'rel_data_hora': DateTime.now().toIso8601String(),
          // ── Campos do filtro antifraude ──────────────────────────────────
          'rel_fraud_status': resultadoAntifraude.statusBanco,
          'rel_fraud_score': resultadoAntifraude.scoreAutenticidade,
          'rel_fraud_reason': resultadoAntifraude.motivoClassificacao,
          'rel_needs_admin_review': resultadoAntifraude.precisaRevisaoAdmin,
          'rel_prioridade': resultadoAntifraude.prioridadeBanco,
        })
        .select();

    if (respostaRelato.isEmpty) {
      throw Exception(
        'O relato foi salvo, mas não retornou os dados. Verifique o RLS.',
      );
    }

    final relatoId = respostaRelato.first['rel_id'];
    final nomeArquivo = '${DateTime.now().millisecondsSinceEpoch}.png';
    final path = 'relatos/$relatoId/$nomeArquivo';

    await supabase.storage
        .from('Fotos_Storage')
        .uploadBinary(path, imagemBytes!);

    await supabase.from('Foto').insert({
      'fto_rel_id': relatoId,
      'fto_url': path,
      'fto_cid_id': userId,
    });
  }

  /// Limpa o formulário após envio bem-sucedido.
  void _limparFormulario() {
    setState(() {
      imagemSelecionada = null;
      imagemBytes = null;
      tipoSelecionado = null;
      nivelSelecionado = null;
      localizacaoSelecionada = null;
      markers.clear();
      _utilizarLocalizacaoAtual = true;
    });
    _descricaoController.clear();
    _getCurrentLocation();
  }

  // ── Fluxo principal de envio com filtro antifraude ───────────────────────

  /// Ponto de entrada quando o usuário toca em "Reportar".
  ///
  /// Fluxo:
  ///   1. Valida campos obrigatórios
  ///   2. Chama o [AntiFraudeService] (mostra diálogo de loading)
  ///   3a. Se legítimo → grava direto no Supabase
  ///   3b. Se suspeito → mostra diálogo ao usuário
  ///     3b-i.  Confirma → grava com flag de revisão pendente
  ///     3b-ii. Cancela  → retorna ao formulário para correção
  Future<void> enviarRelato() async {
    final supabase = Supabase.instance.client;
    final usuarioLogado = supabase.auth.currentUser;

    if (usuarioLogado == null) {
      _mostrarSnackBar(
        'Erro: Você precisa estar logado para enviar um relato.',
        Colors.red,
      );
      return;
    }

    if (!_validarCampos()) return;

    final String tipoDesastre = _mapearTipoDesastre(tipoSelecionado);
    final String nivelRisco = _mapearNivelRisco(nivelSelecionado);
    final String descricao = _descricaoController.text.trim();
    final String userId = usuarioLogado.id;
    final String pontoGeografico =
        'POINT(${localizacaoSelecionada!.longitude} ${localizacaoSelecionada!.latitude})';

    // ── Etapa 1: Exibe diálogo de análise e chama o filtro antifraude ────
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DialogoAnalisandoRelato(),
    );

    ResultadoAntifraude resultado;
    try {
      resultado = await _antiFraudeService.analisarRelato(
        tipoDesastre: tipoDesastre,
        nivelGravidade: nivelRisco,
        descricao: descricao,
        latitude: localizacaoSelecionada!.latitude,
        longitude: localizacaoSelecionada!.longitude,
        imagemBytes: imagemBytes!,
        mimeTypeImagem: imagemSelecionada?.extension?.toLowerCase() == 'png'
            ? 'image/png'
            : 'image/jpeg',
      );
    } catch (e) {
      resultado = ResultadoAntifraude.erro(e.toString());
    }

    // ── Fecha o diálogo de loading ────────────────────────────────────────
    if (!mounted) return;
    Navigator.of(context).pop();

    // ── Etapa 2: Decide o próximo passo com base no resultado ─────────────
    if (resultado.status == StatusAntifraude.legitimo) {
      // ✅ Relato legítimo → grava normalmente
      await _concluirEnvio(
        tipoDesastre: tipoDesastre,
        nivelRisco: nivelRisco,
        descricao: descricao,
        userId: userId,
        pontoGeografico: pontoGeografico,
        resultado: resultado,
      );
    } else {
      // ⚠️ Suspeito → mostra diálogo de aviso ao usuário
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoRelatoSuspeito(
          resultado: resultado,
          onConfirmarEnvio: () async {
            Navigator.of(context).pop(); // fecha o diálogo de suspeita
            await _concluirEnvio(
              tipoDesastre: tipoDesastre,
              nivelRisco: nivelRisco,
              descricao: descricao,
              userId: userId,
              pontoGeografico: pontoGeografico,
              resultado: resultado,
            );
          },
          onCancelar: () {
            Navigator.of(context).pop(); // fecha o diálogo, volta ao form
          },
        ),
      );
    }
  }

  /// Executa a gravação no banco e exibe feedback de sucesso/erro.
  Future<void> _concluirEnvio({
    required String tipoDesastre,
    required String nivelRisco,
    required String descricao,
    required String userId,
    required String pontoGeografico,
    required ResultadoAntifraude resultado,
  }) async {
    try {
      await _gravarNoSupabase(
        tipoDesastre: tipoDesastre,
        nivelRisco: nivelRisco,
        descricao: descricao,
        userId: userId,
        pontoGeografico: pontoGeografico,
        resultadoAntifraude: resultado,
      );
      _limparFormulario();

      final mensagem = resultado.precisaRevisaoAdmin
          ? 'Relato enviado! Aguardando revisão de um administrador.'
          : 'Relato enviado com sucesso!';
      _mostrarSnackBar(mensagem, Colors.green);
    } catch (e) {
      _mostrarSnackBar('Erro ao enviar: $e', Colors.red);
    }
  }

  void _mostrarSnackBar(String texto, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), backgroundColor: cor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: _scrollPhysics,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 50),
                    Text(
                      'Insira as informações para reportar:',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    SizedBox(height: 20),

                    // Seleção de imagem: caixa tracejada "Adicionar" + caixa decorativa
                    _buildImagePicker(),
                    SizedBox(height: 25),

                    Text(
                      'Escolha o tipo de desastre:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    SizedBox(height: 15),

                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _iconDesastre(
                          0,
                          'gfx/png/icons/tipo_inundacao.png',
                          'Alagamento',
                          Icons.water_drop_outlined,
                        ),
                        _iconDesastre(
                          1,
                          'gfx/png/icons/tipo_tornado.png',
                          'Tornado',
                          Icons.cyclone_outlined,
                        ),
                        _iconDesastre(
                          2,
                          'gfx/png/icons/tipo_deslizamento.png',
                          'Desabamento',
                          Icons.terrain_outlined,
                        ),
                        _iconDesastre(
                          3,
                          'gfx/png/icons/tipo_tempestade.png',
                          'Chuva Forte',
                          Icons.thunderstorm_outlined,
                        ),
                      ],
                    ),

                    // Caixinha com a descrição do tipo selecionado (some/aparece animando)
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: tipoSelecionado == null
                          ? SizedBox(width: double.infinity)
                          : Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(top: 14),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _descricaoTipo(tipoSelecionado),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                    ),
                    SizedBox(height: 25),

                    // ── Campo de descrição textual ─────────────────────
                    Text(
                      'Descreva o que está acontecendo:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _descricaoController,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText:
                            'Ex.: A rua está completamente alagada, a água já chegou no joelho...'
                            ' (opcional, mas ajuda na validação)',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.black38,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFC1272D),
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.all(14),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      style: TextStyle(fontSize: 14),
                    ),
                    SizedBox(height: 20),

                    Text(
                      'Escolha o nível de severidade:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    SizedBox(height: 15),

                    // Seletor animado de severidade (a "pílula" desliza e muda de cor)
                    _buildSeveridadeSelector(),
                    SizedBox(height: 25),

                    Text(
                      'Escolha o local do desastre:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                    SizedBox(height: 15),

                    Listener(
                      onPointerDown: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          setState(
                            () => _scrollPhysics =
                                const NeverScrollableScrollPhysics(),
                          );
                        }
                      },
                      onPointerUp: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          setState(
                            () =>
                                _scrollPhysics = const ClampingScrollPhysics(),
                          );
                        }
                      },
                      onPointerCancel: (event) {
                        if (event.kind == PointerDeviceKind.touch) {
                          setState(
                            () =>
                                _scrollPhysics = const ClampingScrollPhysics(),
                          );
                        }
                      },
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          GestureBinding.instance.pointerSignalResolver
                              .register(event, (event) {});
                        }
                      },
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade400),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: _isLoadingMap
                              ? Center(child: CircularProgressIndicator())
                              : GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target:
                                        localizacaoSelecionada ??
                                        const LatLng(-23.5505, -46.6333),
                                    zoom: 15,
                                  ),
                                  onMapCreated: (controller) =>
                                      mapController = controller,
                                  markers: markers,
                                  onTap: (LatLng posicao) {
                                    setState(() {
                                      _utilizarLocalizacaoAtual = false;
                                      localizacaoSelecionada = posicao;
                                      _atualizarMarcador(posicao);
                                    });
                                  },
                                ),
                        ),
                      ),
                    ),
                    SizedBox(height: 10),

                    Row(
                      children: [
                        Checkbox(
                          value: _utilizarLocalizacaoAtual,
                          onChanged: (bool? valor) {
                            if (valor == true) {
                              setState(() => _utilizarLocalizacaoAtual = true);
                              _getCurrentLocation();
                            }
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Utilizar minha localização atual.',
                            style: TextStyle(
                              fontSize: 14,
                              color: acessibilidade.corPrimaria,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: enviarRelato,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFC1272D),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Reportar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Caixa de seleção de imagem: a caixa da esquerda ("Adicionar") é o botão
  // que abre o seletor; a preview da foto escolhida aparece na caixa da
  // direita (em vez de substituir o botão "Adicionar").
  Widget _buildImagePicker() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: selecionarImagem,
            child: SizedBox(
              height: 92,
              child: CustomPaint(
                painter: _DashedBorderPainter(
                  color: Colors.black45,
                  radius: 12,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 26,
                        color: Colors.black54,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Adicionar',
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: selecionarImagem, // também permite trocar a foto por aqui
            child: Container(
              height: 92,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: imagemBytes == null
                  ? null
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        imagemBytes!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // Seletor de severidade em formato de pílula com 3 opções. O preenchimento
  // colorido desliza (AnimatedPositioned) e troca de cor (AnimatedContainer)
  // conforme a opção escolhida.
  Widget _buildSeveridadeSelector() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double largura = constraints.maxWidth;
        final double larguraItem = largura / _opcoesSeveridade.length;
        final int indiceAtivo = nivelSelecionado ?? 0;

        return Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Stack(
            children: [
              if (nivelSelecionado != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: larguraItem * indiceAtivo,
                  top: 0,
                  bottom: 0,
                  width: larguraItem,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _coresSeveridade[indiceAtivo],
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              Row(
                children: List.generate(_opcoesSeveridade.length, (index) {
                  final bool selecionado = nivelSelecionado == index;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => nivelSelecionado = index),
                      child: SizedBox(
                        height: 46,
                        child: Center(
                          child: Text(
                            _opcoesSeveridade[index],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: selecionado
                                  ? Colors.white
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconDesastre(
    int valor,
    String caminhoAsset,
    String nomeDesastre,
    IconData iconeFallback,
  ) {
    bool selecionado = tipoSelecionado == valor;
    return GestureDetector(
      onTap: () => setState(() => tipoSelecionado = valor),
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selecionado ? Colors.blue.shade50 : Colors.white,
                border: Border.all(
                  color: selecionado
                      ? Colors.blue.shade700
                      : Colors.grey.shade300,
                  width: selecionado ? 2.6 : 1.4,
                ),
              ),
              child: Image.asset(
                caminhoAsset,
                width: 38,
                height: 38,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    iconeFallback,
                    color: Colors.blue.shade300,
                    size: 38,
                  );
                },
              ),
            ),
            SizedBox(height: 6),
            Text(
              nomeDesastre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selecionado ? FontWeight.bold : FontWeight.normal,
                color: selecionado ? Colors.blue.shade900 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Desenha uma borda tracejada arredondada (usada na caixa "Adicionar" imagem).
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  const _DashedBorderPainter({
    this.color = Colors.black45,
    this.radius = 12,
  }) : strokeWidth = 1.4,
       dashWidth = 6,
       dashSpace = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final dashedPath = Path();

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double proximo = distance + dashWidth;
        dashedPath.addPath(
          metric.extractPath(distance, proximo.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = proximo + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}
