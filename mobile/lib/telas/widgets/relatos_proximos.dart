import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controles/controle_acessibilidade.dart';
import 'package:prever/services/relatos_proximos_service.dart';

class RelatosProximos extends StatefulWidget {
  final bool ativa;
  final ValueChanged<RelatoProximo>? onAbrirRelato;
  final Future<List<RelatoProximo>> Function() carregar;
  final Future<String?> Function(String) carregarFoto;

  const RelatosProximos({
    super.key,
    required this.ativa,
    this.onAbrirRelato,
    this.carregar = carregarRelatosProximos,
    this.carregarFoto = carregarFotoRelato,
  });

  @override
  State<RelatosProximos> createState() => _RelatosProximosState();
}

class _RelatosProximosState extends State<RelatosProximos> {
  List<RelatoProximo> _relatos = [];
  bool _carregando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    if (widget.ativa) _atualizar();
  }

  @override
  void didUpdateWidget(covariant RelatosProximos oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ativa && !oldWidget.ativa) _atualizar();
  }

  Future<void> _atualizar() async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final relatos = await widget.carregar();
      if (!mounted) return;
      setState(() => _relatos = relatos);
    } on LocalizacaoIndisponivel catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _erro = 'Não foi possível carregar os relatos. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  IconData _icone(String tipo) => switch (tipo) {
    'Chuva Forte' => Icons.thunderstorm_outlined,
    'Alagamento' => Icons.water,
    'Desabamento' => Icons.landslide_outlined,
    'Tornado' => Icons.air,
    _ => Icons.warning_amber_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cores = context.watch<AccessibilityController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Relatos próximos de você',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: cores.corPrimaria,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar relatos',
              onPressed: _carregando ? null : _atualizar,
              icon: Icon(Icons.refresh, color: cores.corPrimaria),
            ),
          ],
        ),
        Text(
          'Em um raio de 3 km • Mais próximos primeiro',
          style: TextStyle(fontSize: 13, color: cores.corPrimaria),
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cores.fundo,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: cores.corSecundaria),
          ),
          child: _carregando
              ? Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _erro != null || _relatos.isEmpty
              ? Text(
                  _erro ?? 'Nenhum relato encontrado a até 3 km de você.',
                  style: TextStyle(color: cores.corPrimaria),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _relatos.length; i++) ...[
                      if (i > 0)
                        Divider(height: 28, color: cores.corSecundaria),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FotoRelato(
                            carregar: widget.carregarFoto,
                            key: ValueKey(_relatos[i].id ?? i),
                            relato: _relatos[i],
                            icone: _icone(_relatos[i].tipo),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _relatos[i].tipo,
                                  style: TextStyle(
                                    color: cores.corPrimaria,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _relatos[i].distanciaMetros < 1000
                                      ? '${_relatos[i].distanciaMetros.round()} m de você'
                                      : '${(_relatos[i].distanciaMetros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km de você',
                                  style: TextStyle(
                                    color: cores.corPrimaria,
                                    fontSize: 13,
                                  ),
                                ),
                                if (_relatos[i].descricao.isNotEmpty) ...[
                                  SizedBox(height: 6),
                                  Text(
                                    _relatos[i].descricao,
                                    style: TextStyle(
                                      color: cores.corPrimaria,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                                SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed:
                                      widget.onAbrirRelato == null ||
                                          _relatos[i].id == null ||
                                          _relatos[i].latitude == null ||
                                          _relatos[i].longitude == null
                                      ? null
                                      : () =>
                                            widget.onAbrirRelato!(_relatos[i]),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: cores.corPrimaria,
                                    side: BorderSide(
                                      color: cores.corSecundaria,
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.location_on_outlined,
                                    size: 18,
                                  ),
                                  label: Text('Ver no mapa'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class FotoRelato extends StatefulWidget {
  final RelatoProximo relato;
  final IconData icone;
  final Future<String?> Function(String) carregar;

  const FotoRelato({
    super.key,
    required this.relato,
    required this.icone,
    this.carregar = carregarFotoRelato,
  });

  @override
  State<FotoRelato> createState() => _FotoRelatoState();
}

class _FotoRelatoState extends State<FotoRelato> {
  late Future<String?> _foto;

  Future<String?> _carregar() => widget.relato.id == null
      ? Future.value(null)
      : widget.carregar(widget.relato.id!);

  @override
  void initState() {
    super.initState();
    _foto = _carregar();
  }

  @override
  void didUpdateWidget(covariant FotoRelato oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.relato, oldWidget.relato)) _foto = _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final cores = context.watch<AccessibilityController>();
    final semFoto = Tooltip(
      message: 'Foto indisponível',
      child: Center(
        child: Icon(widget.icone, color: cores.corPrimaria, size: 32),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        color: cores.corSecundaria.withValues(alpha: 0.18),
        child: FutureBuilder<String?>(
          future: _foto,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (snapshot.hasError || snapshot.data == null) return semFoto;
            return Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              semanticLabel: 'Foto da ocorrência: ${widget.relato.tipo}',
              errorBuilder: (_, error, stack) => semFoto,
            );
          },
        ),
      ),
    );
  }
}
