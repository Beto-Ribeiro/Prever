import 'package:prever/telas/cadastro_tela.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exportador_import.dart';
import 'package:prever/main.dart';

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
              painter: AbstractBackgroundPainter(),
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
                    padding: const EdgeInsets.fromLTRB(
                      25,
                      0,
                      25,
                      25,
                    ),
                    width: double.infinity,
                    height: 150,
                    decoration: const BoxDecoration(
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
                          onPressed: () {widget.onChangePage(8);},
                          child: Text(
                            'Entrar',
                              style: TextStyle(color: Colors.white)
                          ),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromRGBO(24, 57, 92, 1),
                              minimumSize: Size(139, 40)
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {widget.onChangePage(5);},
                          child: Text(
                            'Registrar',
                              style: TextStyle(color: Colors.white)
                          ),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Color.fromRGBO(24, 57, 92, 1),
                              minimumSize: Size(139, 40)
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SvgPicture.asset("gfx/svg/Image/Prever_logo.svg", semanticsLabel: "Logo Prever",
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
