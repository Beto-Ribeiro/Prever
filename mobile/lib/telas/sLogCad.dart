import 'exportador_import.dart';

class SLogCad extends StatefulWidget {
  final Function(int) onChangePage;

  const SLogCad({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<SLogCad> createState() => _sLogCad_telaState();
}

class _sLogCad_telaState extends State<SLogCad> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueGrey[600],

      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: AbstractBackgroundPainter(
                primaryColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.3),
                secondaryColor: Theme.of(
                  context,
                ).colorScheme.secondary.withValues(alpha: 0.3),
                tertiaryColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),

          SafeArea(
            child: Container(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Column(
                verticalDirection: VerticalDirection.up,

                mainAxisSize: MainAxisSize.max,

                children: <Widget>[
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      25,
                      0,
                      25,
                      25,
                    ),
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 35,
                      children: <Widget>[
                        ElevatedButton(
                          onPressed: () {
                            widget.onChangePage(8);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(24, 57, 92, 1),
                            minimumSize: Size(139, 40),
                          ),
                          child: Text(
                            'Entrar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            widget.onChangePage(5);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color.fromRGBO(24, 57, 92, 1),
                            minimumSize: Size(139, 40),
                          ),
                          child: Text(
                            'Registrar',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SvgPicture.asset(
                        "gfx/svg/Image/Prever_logo.svg",
                        semanticsLabel: "Logo Prever",
                        height: 120,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
