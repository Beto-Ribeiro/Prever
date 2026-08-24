import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'exportador_import.dart';
import '../controles/botao_acessibilidade.dart';
import '../controles/controle_acessibilidade.dart';

class TelaPerfil extends StatefulWidget {
  final Function(int) onChangePage;

  const TelaPerfil({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<TelaPerfil> createState() => _TelaPerfilState();
}

class _TelaPerfilState extends State<TelaPerfil> {
  final supabase = Supabase.instance.client;

  final double alturaCard = 90;

  Color azul = const Color(0xFF1D3557);
  Color azulClaro = const Color(0xFF8FB3D9);

  String nome = '';
  String cpf = '';
  String alergias = '';
  String observacoes = '';
  String tipoUsuario = '';
  String tipoSanguineo = '';
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _esperarSessaoECarregar();
  }

  Future<void> _esperarSessaoECarregar() async {
    if (supabase.auth.currentUser != null) {
      carregarDados();
      return;
    }
    supabase.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        carregarDados();
      }
    });
  }

  Future<void> carregarDados() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        setState(() => carregando = false);
        return;
      }

      try {
        final perfil = await supabase
            .from('Perfis')
            .select()
            .eq('prf_id', userId)
            .limit(1)
            .single();
        setState(() {
          nome = perfil['prf_nome'] ?? '';
          tipoUsuario = perfil['prf_tipo'] ?? '';
        });
      } catch (e) {}

      try {
        final cidadao = await supabase
            .from('Cidadao')
            .select()
            .eq('cid_id', userId)
            .limit(1)
            .single();
        setState(() {
          cpf = cidadao['cid_cpf'] ?? '';
        });
      } catch (e) {}

      try {
        final historico = await supabase
            .from('Historico_Medicacao_Cidadao')
            .select()
            .eq('hmc_cid_id', userId)
            .limit(1)
            .single();
        setState(() {
          tipoSanguineo = historico['hmc_tipo_sanguineo'] ?? '';
          alergias = historico['hmc_alergias'] ?? '';
          observacoes = historico['hmc_doencas_cronicas'] ?? '';
        });
      } catch (e) {}

      setState(() => carregando = false);
    } catch (e) {
      setState(() => carregando = false);
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
        child: Stack(
          children: [
            carregando
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton(
                              onPressed: () => widget.onChangePage(0),
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
                          "Perfil do usuário",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 15),
                        Container(
                          width: 95,
                          height: 95,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 45,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        campoTexto(nome, 28, true),
                        campoTexto(tipoUsuario, 16, false),
                        campoTexto(cpf, 16, false),
                        const SizedBox(height: 20),
                        campoTipoSanguineo(),
                        const SizedBox(height: 30),
                        titulo("Alergias"),
                        areaTexto(alergias),
                        const SizedBox(height: 30),
                        titulo("Doenças"),
                        areaTexto(observacoes),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),

            // ── Botão de acessibilidade (canto superior direito) ─────
            BotaoAcessibilidade(
              onEditarPerfil: () => widget.onChangePage(10),
              onLogout: () => widget.onChangePage(7),
            ),
          ],
        ),
      ),
    );
  }

  Widget campoTexto(String texto, double tamanho, bool destaque) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        texto.isEmpty ? '—' : texto,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: tamanho,
          fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
          color: destaque ? azul : azulClaro,
        ),
      ),
    );
  }

  Widget campoTipoSanguineo() {
    return Container(
      height: alturaCard,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: azulClaro),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            "Tipo sanguíneo",
            style: TextStyle(fontSize: 12, color: azulClaro),
          ),
          const SizedBox(height: 4),
          Text(
            tipoSanguineo.isEmpty ? '—' : tipoSanguineo,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: azul,
            ),
          ),
        ],
      ),
    );
  }

  Widget titulo(String texto) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: azul,
        ),
      ),
    );
  }

  Widget areaTexto(String texto) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: azulClaro),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto.isEmpty ? "Nenhuma informação" : texto,
        style: TextStyle(fontSize: 16, color: azul),
      ),
    );
  }
}
