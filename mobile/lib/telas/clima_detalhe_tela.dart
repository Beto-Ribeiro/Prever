import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../controles/controle_acessibilidade.dart';
import 'icone_clima.dart';

class ClimaDetalheTela extends StatelessWidget {
  final String cidade;
  final String temperatura;
  final String descricao;

  // Código da condição climática atual (campo "id" da API OpenWeatherMap)
  // e código do ícone (ex: "01d", "10n"), usados para escolher o ícone certo.
  final String? idAtual;
  final String? iconeAtual;

  // Previsão por hora. Cada item pode conter:
  // {"hora": "15h", "temperatura": "20°", "descricao": "céu limpo",
  //  "id": "800", "icone": "01d"}
  // Opcional: se não for passada, mostra um exemplo (mock) só para visualização do layout.
  final List<Map<String, String>>? previsaoHoraria;

  // Opcional: repassado de quem abriu esta tela, usado pelo ícone de perfil
  // para trocar de página (mesmo comportamento do ContainerPerfilSuperior).
  final Function(int)? onChangePage;

  const ClimaDetalheTela({
    super.key,
    required this.cidade,
    required this.temperatura,
    required this.descricao,
    this.idAtual,
    this.iconeAtual,
    this.previsaoHoraria,
    this.onChangePage,
  });

  static const List<Map<String, String>> _previsaoExemplo = [
    {"hora": "15h", "temperatura": "20°", "descricao": "céu limpo"},
    {"hora": "16h", "temperatura": "19°", "descricao": "nublado"},
    {"hora": "17h", "temperatura": "17°", "descricao": "nublado"},
    {"hora": "18h", "temperatura": "17°", "descricao": "nublado"},
  ];

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();
    final previsao = previsaoHoraria ?? _previsaoExemplo;

    final horaAtual = TimeOfDay.now();
    final horaFormatada =
        "${horaAtual.hour.toString().padLeft(2, '0')}h${horaAtual.minute.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Cabeçalho: voltar + ícone de perfil (mesmo do ContainerPerfilSuperior)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: acessibilidade.corPrimaria,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(33),
                      onTap: () {
                        // Armazena o callback antes de modificar a navegação
                        final Function(int)? callback = onChangePage;
                        // Volta para a tela principal
                        Navigator.popUntil(context, (route) => route.isFirst);
                        // Garante que a navegação foi processada antes de chamar o callback
                        Future.microtask(() {
                          if (callback != null) {
                            callback(8);
                          }
                        });
                      },
                      child: Container(
                        width: 65,
                        height: 65,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          'gfx/svg/icons/User_Icon.svg',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10),

            // Temperatura em destaque
            Text(
              temperatura,
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w600,
                color: acessibilidade.corPrimaria,
              ),
            ),

            SizedBox(height: 10),

            // Ícone grande do clima atual
            Icon(
              iconeParaClima(
                icone: iconeAtual,
                id: idAtual,
                descricao: descricao,
              ),
              size: 130,
              color: acessibilidade.corPrimaria,
            ),

            SizedBox(height: 10),

            Text(
              cidade,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: acessibilidade.corPrimaria,
              ),
            ),
            SizedBox(height: 4),
            Text(
              horaFormatada,
              style: TextStyle(
                fontSize: 15,
                color: acessibilidade.corPrimaria.withValues(alpha: 0.8),
              ),
            ),

            SizedBox(height: 20),

            // Seção inferior curva com a previsão por hora
            Expanded(
              child: ClipPath(
                clipper: _TopoCurvoClipper(),
                child: Container(
                  width: double.infinity,
                  color: acessibilidade.corSecundaria,
                  padding: EdgeInsets.fromLTRB(18, 40, 18, 20),
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: previsao.map((item) {
                          return _CardHora(
                            hora: item["hora"] ?? "",
                            temperatura: item["temperatura"] ?? "",
                            icone: iconeParaClima(
                              icone: item["icone"],
                              id: item["id"],
                              descricao: item["descricao"],
                            ),
                            cor: acessibilidade.corPrimaria,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Card individual de cada horário na previsão.
class _CardHora extends StatelessWidget {
  final String hora;
  final String temperatura;
  final IconData icone;
  final Color cor;

  const _CardHora({
    required this.hora,
    required this.temperatura,
    required this.icone,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 65,
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            hora,
            style: TextStyle(fontSize: 13, color: cor),
          ),
          SizedBox(height: 8),
          Icon(icone, color: cor, size: 22),
          SizedBox(height: 8),
          Text(
            temperatura,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

// Desenha a curva no topo da seção azul, como na referência de design.
class _TopoCurvoClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, 60);
    path.quadraticBezierTo(size.width / 2, -40, size.width, 60);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
