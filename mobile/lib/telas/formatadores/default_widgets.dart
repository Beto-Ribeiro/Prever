import '../exportador_import.dart';

class ContainerPerfilSuperior extends StatelessWidget {
  final Function(int) onChangePage;
  final String nome;

  const ContainerPerfilSuperior({
    super.key,
    required this.onChangePage,
    required this.nome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
      padding: EdgeInsets.fromLTRB(20, 0, 15, 0),
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          mainAxisSize: MainAxisSize.max,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  onChangePage(9);
                },

                child: Container(
                  width: 30,
                  height: 30,

                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                  ),

                  child: SvgPicture.asset(
                    'gfx/svg/icons/bell.svg',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            Text(
              nome,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  onChangePage(9);
                },

                child: Container(
                  width: 50,
                  height: 50,

                  decoration: BoxDecoration(
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
    );
  }
}

class PinsVisao extends StatefulWidget {
  final Function() FecharPinVisao;
  final String pinID;
  const PinsVisao({super.key,
    required this.pinID,
    required this.FecharPinVisao,
  });

  @override
  State<PinsVisao> createState() => _PinsVisaoState();
}

class _PinsVisaoState extends State<PinsVisao> {
  final supabase = Supabase.instance.client;

  String? imagemURL;
  bool carregando = true;

  String? TipoDesatrePinVisao;
  String? MagnitudePinVisao;

  Future<void> carregarImagem(String id) async {
    try {
      // caminho da pasta dentro do bucket
      final caminhoPasta = 'relatos/$id';

      // lista os arquivos existentes nessa pasta
      final arquivos = await supabase.storage
          .from('Fotos_Storage')
          .list(path: caminhoPasta);

      if (!mounted || id != widget.pinID) return;
      if (arquivos.isEmpty) {
        setState(() {
          imagemURL = null;
          carregando = false;
        });

        return;
      }

      // pega o primeiro arquivo da pasta
      final nomeArquivo = arquivos.first.name;

      // caminho completo dentro do bucket
      final caminhoArquivo = '$caminhoPasta/$nomeArquivo';

      // gera URL privada por 1 hora
      final url = await supabase.storage
          .from('Fotos_Storage')
          .createSignedUrl(
            caminhoArquivo,
            3600,
          );

      if (!mounted || id != widget.pinID) return;
      setState(() {
        imagemURL = url;
        carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar imagem: $e');

      if (!mounted || id != widget.pinID) return;
      setState(() {
        imagemURL = null;
        carregando = false;
      });
    }
  }

  Future<void> CarregarDadosPin(String ID) async {
    try {
      final dados = await supabase
          .from('relatos_mapa')
          .select('rel_tipo_desastre, rel_descricao')
          .eq('rel_id', ID)
          .single();

      if (!mounted || ID != widget.pinID) return;

      setState(() {
        TipoDesatrePinVisao = dados['rel_tipo_desastre'];
        MagnitudePinVisao = dados['rel_descricao'];
      });
    } catch (e) {
      if (!mounted || ID != widget.pinID) return;

      setState(() {
        TipoDesatrePinVisao = e.toString();
        MagnitudePinVisao = e.toString();
      });
    }
  }

  @override
  void didUpdateWidget(covariant PinsVisao oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.pinID != widget.pinID) {
      setState(() {
        carregando = true;
        imagemURL = null;
        TipoDesatrePinVisao = null;
        MagnitudePinVisao = null;
      });

      carregarImagem(widget.pinID);
      CarregarDadosPin(widget.pinID);
    }
  }

  @override
  void initState() {
    super.initState();

    CarregarDadosPin(widget.pinID);
    carregarImagem(widget.pinID);
  }

  double VerticalResponsivePadding = 0;
  double HorizontalResponsivePadding = 0;

  @override
  Widget build(BuildContext context) {
    //VARIAVEIS DE LAYOUT
    VerticalResponsivePadding = MediaQuery.sizeOf(context).height * 0.05;
    HorizontalResponsivePadding = MediaQuery.sizeOf(context).width * 0.1;

    return Column(
      mainAxisSize: MainAxisSize.max,
      verticalDirection: VerticalDirection.up,
      children: [
        Container(
          height: MediaQuery.sizeOf(context).height * 0.45,
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            HorizontalResponsivePadding,
            10,
            HorizontalResponsivePadding,
            90,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () {
                      widget.FecharPinVisao();
                    },
                    child: Icon(
                      Icons.close,
                      color: Colors.black,
                      size: VerticalResponsivePadding,
                    ),
                  ),
                ],
              ),
              Container(
                height: 10,
              ),
              Container(
                height: MediaQuery.sizeOf(context).height * 0.15,
                width: MediaQuery.sizeOf(context).width * 0.9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  color: Colors.grey,
                ),
                alignment: AlignmentGeometry.topCenter,
                clipBehavior: Clip.hardEdge,

                child: carregando
                    ? const CircularProgressIndicator()
                    : imagemURL == null
                    ? Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset("gfx/png/icons/camera-off.png", scale: 2,),
                          Text('Nenhuma imagem encontrada'),
                        ],
                      )
                    : Image.network(
                        imagemURL!,
                        fit: BoxFit.fitHeight,
                      ),
              ),
              Container(
                alignment: AlignmentGeometry.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Tipo de desastre: ",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        Text(
                          TipoDesatrePinVisao ?? 'Carregando...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          "Magnitude: ",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.left,
                        ),
                        Text(
                          MagnitudePinVisao ?? 'Carregando...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PinsMapa {
  final double latitude;
  final double longitude;

  Offset screenPosition;

  PinsMapa({
    required this.latitude,
    required this.longitude,
    this.screenPosition = Offset.zero,
  });
}

class UltimosRelatosContainer extends StatefulWidget{
 const UltimosRelatosContainer({
   super.key
});

  @override
  State<UltimosRelatosContainer> createState() => _ultimosRelatosContainerState();
}

class _ultimosRelatosContainerState extends State<UltimosRelatosContainer>{

  final supabase = Supabase.instance.client;

  List<dynamic> relatos = [];

  String? imagemURL;
  bool carregando = true;

  Future<void> carregarImagem(String id) async {
    try {
      // caminho da pasta dentro do bucket
      final caminhoPasta = 'relatos/$id';

      // lista os arquivos existentes nessa pasta
      final arquivos = await supabase.storage
          .from('Fotos_Storage')
          .list(path: caminhoPasta);

      if (arquivos.isEmpty) {
        setState(() {
          imagemURL = null;
          carregando = false;
        });

        return;
      }

      // pega o primeiro arquivo da pasta
      final nomeArquivo = arquivos.first.name;

      // caminho completo dentro do bucket
      final caminhoArquivo = '$caminhoPasta/$nomeArquivo';

      // gera URL privada por 1 hora
      final url = await supabase.storage
          .from('Fotos_Storage')
          .createSignedUrl(
        caminhoArquivo,
        3600,
      );

      setState(() {
        imagemURL = url;
        carregando = false;
      });
    } catch (e) {
      debugPrint('Erro ao carregar imagem: $e');

      setState(() {
        imagemURL = null;
        carregando = false;
      });
    }
  }

  Future<void> BuscarUltimosRelatos() async {
    final data = await supabase.from('relato').select('rel_id').order('rel_data_hora', ascending: false);

    for(final relato in data){
      carregarImagem(relato["rel_id"]);
    }


  }

  @override
  Widget build(BuildContext context){
    return Container(
      child: Column(
        children: [
          for(final r in relatos)
            Container()
      ]
      ),
    );
  }
}
