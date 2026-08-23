import '../exportador_import.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final user = Supabase.instance.client.auth.currentUser;
    return Container(
      decoration: BoxDecoration(color: Color.fromRGBO(9, 22, 46, 1)),
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
                  onChangePage(8);
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
                  onChangePage(8);
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
  String pinID;
  PinsVisao({required this.pinID});

  @override
  State<PinsVisao> createState() => _PinsVisaoState();
}

class _PinsVisaoState extends State<PinsVisao> {
  final supabase = Supabase.instance.client;

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
      print('Erro ao carregar imagem: $e');

      setState(() {
        imagemURL = null;
        carregando = false;
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
      });

      carregarImagem(widget.pinID);
    }
  }

  @override
  void initState() {
    super.initState();

    carregarImagem(widget.pinID);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      verticalDirection: VerticalDirection.up,
      children: [
        Container(
          height: 25,
          width: double.infinity,
        ),
        Container(
          height: MediaQuery.sizeOf(context).height / 2.25,
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Imagem'),
              Container(
                height: MediaQuery.sizeOf(context).height * 0.2,
                width: MediaQuery.sizeOf(context).width * 0.9,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  color: Colors.grey,
                ),
                clipBehavior: Clip.hardEdge,

                child: carregando
                    ? const CircularProgressIndicator()
                    : imagemURL == null
                    ? const Text('Nenhuma imagem encontrada')
                    : Image.network(
                  imagemURL!,
                  fit: BoxFit.fitHeight,
                ),
              )

            ]),
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
