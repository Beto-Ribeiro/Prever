import 'package:branch1/telas/cadastro_tela.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exportador_import.dart';
import 'package:branch1/main.dart';

class sLogCad extends StatefulWidget {
  final Function(int) onChangePage;

  const sLogCad({
    super.key,
    required this.title,
    required this.onChangePage,
  });

  final String title;

  @override
  State<sLogCad> createState() => _sLogCad_telaState();
}

class _sLogCad_telaState extends State<sLogCad> {
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
                          onPressed: () {widget.onChangePage(7);},
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
                          onPressed: () {widget.onChangePage(4);},
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
                      child: Image.asset(
                        "gfx/png/Image/prever.png",
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
