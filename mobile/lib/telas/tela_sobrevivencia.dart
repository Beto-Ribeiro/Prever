import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controles/controle_acessibilidade.dart';

class TelaSobrevivencia extends StatefulWidget {
  TelaSobrevivencia({super.key});

  @override
  State<TelaSobrevivencia> createState() => _TelaSobrevivenciaState();
}

class _TelaSobrevivenciaState extends State<TelaSobrevivencia> {
  int _indexExpandido = -1;

  final List<Map<String, dynamic>> _conteudoGuia = [
    {
      'titulo': 'Deslizamento',
      'icone': 'gfx/png/icons/tipo_deslizamento.png',
      'antes':
          'Sinais da natureza e estruturais:\nRachaduras novas no solo, postes ou árvores se inclinando, ou águas de riachos que passam de limpas a lamacentas em minutos.',
      'durante': [
        'Se estiver dentro de casa e não puder sair: Afaste-se de paredes externas. Busque abrigo debaixo de uma mesa pesada ou em vãos de portas internas. Se a estrutura começar a colapsar, adote a posição fetal, protegendo a cabeça com os braços.',
        'Se estiver fora de casa: Corra para o terreno mais alto e firme possível, o mais longe possível do caminho da lama. Evite valas, canais ou fundos de vales, pois a lama e os detritos se acumulam nesses locais.',
        'Se for impossível escapar: Aproxime-se de objetos grandes e rígidos que possam criar "bolhões de ar" se você for soterrado (como sofás ou colchões estruturados) e proteja seu rosto para evitar a inalação de poeira e lama.',
      ],
    },
    {
      'titulo': 'Enchente',
      'icone': 'gfx/png/icons/tipo_inundacao.png',
      'antes':
          'Fique atento aos alertas meteorológicos. Suba móveis e eletrodomésticos para os lugares mais altos da casa. Guarde documentos e remédios em sacos plásticos lacrados.',
      'durante': [
        'Não tente atravessar áreas alagadas a pé ou de carro, a força da água pode arrastá-lo facilmente.',
        'Se a água começar a invadir sua residência, desligue a chave geral de energia e suba para o ponto mais alto.',
        'Evite contato direto com a água da enchente para prevenir contaminações e doenças como a leptospirose.',
      ],
    },
    {
      'titulo': 'Tempestade',
      'icone': 'gfx/png/icons/tipo_tempestade.png',
      'antes':
          'Feche bem janelas e portas. Retire aparelhos eletrônicos das tomadas para evitar queimas por surtos de tensão.',
      'durante': [
        'Se estiver na rua, busque abrigo em edificações firmes. Nunca se abrigue debaixo de árvores ou coberturas metálicas.',
        'Evite segurar objetos metálicos longos, como varas de pesca ou guarda-chuvas, e fique longe de cercas de arame.',
        'Se estiver dirigindo, permaneça dentro do veículo. Os pneus oferecem um isolamento seguro contra raios.',
      ],
    },
    {
      'titulo': 'Tornado',
      'icone': 'gfx/png/icons/tipo_tornado.png',
      'antes':
          'Identifique um cômodo seguro na casa, de preferência sem janelas, no subsolo ou no centro da construção.',
      'durante': [
        'Fique longe de janelas, portas e paredes externas, pois os detritos lançados pelo vento são o maior perigo.',
        'Se estiver em um veículo ou estrutura móvel, saia imediatamente e busque um abrigo resistente.',
        'Caso seja pego em campo aberto, deite-se em uma vala ou depressão no solo e cubra a cabeça com as mãos.',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final acessibilidade = context.watch<AccessibilityController>();

    return Scaffold(
      backgroundColor: acessibilidade.fundo,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: acessibilidade.corPrimaria.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: acessibilidade.corPrimaria,
                      ),
                    ),
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: acessibilidade.corPrimaria,
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Guia de sobrevivência',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: acessibilidade.corPrimaria,
              ),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _conteudoGuia.length,
                itemBuilder: (context, index) {
                  final item = _conteudoGuia[index];
                  bool estaExpandido = _indexExpandido == index;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _indexExpandido = estaExpandido ? -1 : index;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: acessibilidade.corPrimaria,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Image.asset(
                                item['icone'] as String,
                                width: 46,
                                height: 46,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.warning_amber_rounded,
                                    color: acessibilidade.corSecundaria,
                                    size: 32,
                                  );
                                },
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  item['titulo'] as String,
                                  style: TextStyle(
                                    color: acessibilidade.corSecundaria,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(
                                estaExpandido
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: acessibilidade.corSecundaria,
                              ),
                            ],
                          ),
                          if (estaExpandido) ...[
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 15),
                            Text(
                              '1-   Antes do Desastre:',
                              style: TextStyle(
                                color: acessibilidade.corSecundaria,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              item['antes'] as String,
                              style: const TextStyle(
                                color: Color(0xFFE4E4E4),
                                fontSize: 14,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '2-   Durante o Desastre:',
                              style: TextStyle(
                                color: acessibilidade.corSecundaria,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            ...(item['durante'] as List<String>)
                                .asMap()
                                .entries
                                .map((entry) {
                                  int passoIdx = entry.key;
                                  String textoPasso = entry.value;
                                  String letra = String.fromCharCode(
                                    65 + passoIdx,
                                  );

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: Colors.white24,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            letra,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            textoPasso,
                                            style: const TextStyle(
                                              color: Color(0xFFD8D8D8),
                                              fontSize: 14,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
