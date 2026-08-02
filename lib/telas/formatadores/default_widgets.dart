import '../exportador_import.dart';



class ContainerPerfilSuperior extends StatelessWidget{

  final Function(int) onChangePage;
  final String nome;

  const ContainerPerfilSuperior({
    super.key,
    required this.onChangePage,
    required this.nome,
  });

  @override
  Widget build(BuildContext context){
    final user = Supabase.instance.client.auth.currentUser;
    return Container(
      decoration: BoxDecoration(
        color: Color.fromRGBO(9, 22, 46, 1)
      ),
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
            Text(nome, style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),),
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