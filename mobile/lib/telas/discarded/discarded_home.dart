import '../exportador_import.dart';

class Home_Tela extends StatefulWidget {
  const Home_Tela({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<Home_Tela> createState() => _Home_TelaState();
}

class _Home_TelaState extends State<Home_Tela> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.max,
                children: [
                  Material(
                    color: Colors.transparent,
                    shape: CircleBorder(),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(33),
                      onTap: () {},

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
            SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            "Visão Geral",
                            style: TextStyle(
                              fontSize: 48,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        clipBehavior: Clip.hardEdge,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Stack(
                          children: [
                            Image(
                              image: AssetImage(
                                "gfx/diverse_types/CHUVA.jpg",
                              ),
                              width: double.infinity,
                            ),
                            Positioned(
                              bottom: 16,
                              left: 0,
                              right: 0,

                              child: Center(
                                child: Text(
                                  "São Paulo, 14:00 - Chuva à Vista",

                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: Container(
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
