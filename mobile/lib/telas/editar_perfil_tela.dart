import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../controles/controle_acessibilidade.dart';

class EditarPerfilTela extends StatefulWidget {
  final Function(int) onChangePage;

  const EditarPerfilTela({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<EditarPerfilTela> createState() => _EditarPerfilTelaState();
}

class _EditarPerfilTelaState extends State<EditarPerfilTela> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _alergiasController = TextEditingController();
  final TextEditingController _doencasController = TextEditingController();

  final List<String> _tiposSanguineos = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];
  String? _tipoSanguineoSelecionado;

  bool carregando = true;
  bool salvando = false;

  Color azul = const Color(0xFF1D3557);
  Color azulClaro = const Color(0xFF8FB3D9);

  @override
  void initState() {
    super.initState();
    _carregarDadosAtuais();
  }

  @override
  void dispose() {
    _alergiasController.dispose();
    _doencasController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosAtuais() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => carregando = false);
        return;
      }

      final historico = await supabase
          .from('Historico_Medicacao_Cidadao')
          .select()
          .eq('hmc_cid_id', userId)
          .maybeSingle();

      if (!mounted) return;
      if (historico != null) {
        setState(() {
          _tipoSanguineoSelecionado =
              (historico['hmc_tipo_sanguineo'] as String?)?.isNotEmpty == true
              ? historico['hmc_tipo_sanguineo']
              : null;
          _alergiasController.text = historico['hmc_alergias'] ?? '';
          _doencasController.text = historico['hmc_doencas_cronicas'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados para edição: $e');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> _salvar() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => salvando = true);

    try {
      final existente = await supabase
          .from('Historico_Medicacao_Cidadao')
          .select('hmc_cid_id')
          .eq('hmc_cid_id', userId)
          .maybeSingle();

      final dados = {
        'hmc_cid_id': userId,
        'hmc_tipo_sanguineo': _tipoSanguineoSelecionado ?? '',
        'hmc_alergias': _alergiasController.text.trim(),
        'hmc_doencas_cronicas': _doencasController.text.trim(),
      };

      if (existente == null) {
        await supabase.from('Historico_Medicacao_Cidadao').insert(dados);
      } else {
        await supabase
            .from('Historico_Medicacao_Cidadao')
            .update(dados)
            .eq('hmc_cid_id', userId);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informações salvas com sucesso!')),
      );
      widget.onChangePage(8); // volta para a tela de perfil
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e')),
      );
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();
    azul = acessibilidade.corPrimaria;
    azulClaro = acessibilidade.corSecundaria;

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: carregando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Botão voltar ──────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton(
                            onPressed: salvando
                                ? null
                                : () => widget.onChangePage(8),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromRGBO(
                                228,
                                232,
                                235,
                                0.2,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back,
                              size: 15,
                              color: Color.fromRGBO(228, 232, 235, 1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Text(
                        'Editar informações de saúde',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: azul,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Essas informações ajudam no seu atendimento em caso de emergência.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Tipo sanguíneo ────────────────────────────
                      Text(
                        'Tipo sanguíneo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: azulClaro,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _tipoSanguineoSelecionado,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: azulClaro),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          hintText: 'Selecione',
                        ),
                        items: _tiposSanguineos
                            .map(
                              (tipo) => DropdownMenuItem(
                                value: tipo,
                                child: Text(tipo),
                              ),
                            )
                            .toList(),
                        onChanged: (valor) {
                          setState(() => _tipoSanguineoSelecionado = valor);
                        },
                      ),

                      const SizedBox(height: 24),

                      // ── Alergias ───────────────────────────────────
                      Text(
                        'Alergias',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: azulClaro,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _alergiasController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: azulClaro),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          hintText: 'Ex: alergia a dipirona, amendoim...',
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Doenças ──────────────────────────────────
                      Text(
                        'Doenças crônicas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: azulClaro,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _doencasController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: azulClaro),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                          hintText: 'Ex: diabetes, hipertensão...',
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Botão salvar ────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: salvando ? null : _salvar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: azul,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: salvando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Salvar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
