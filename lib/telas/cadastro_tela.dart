import 'package:branch1/telas/cadastro_tela.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'exportador_import.dart';
import 'package:branch1/main.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class Cadastro_tela extends StatefulWidget {
  final Function(int) onChangePage;
  final Function(String email, String senha) onCadastroPendente;

  const Cadastro_tela({
    super.key,
    required this.title,
    required this.onChangePage,
    required this.onCadastroPendente,
  });

  final String title;

  @override
  State<Cadastro_tela> createState() => _Cadastro_telaState();
}

class _Cadastro_telaState extends State<Cadastro_tela> {
  bool _estaCarregando = false;

  final _NomeController = TextEditingController();

  final _CPFController = TextEditingController();

  final _RgController = TextEditingController();

  final _TelController = TextEditingController();

  final _EmailController = TextEditingController();

  final _SenhaController = TextEditingController();

  final _ConSenhaController = TextEditingController();

  final cpfMask = MaskTextInputFormatter(mask: '###.###.###-##'); 

  final rgMask = MaskTextInputFormatter(mask: '##.###.###-#');

  final telMask = MaskTextInputFormatter(mask: '(##) #####-####');

  Future<void> _enviarDados() async {
    setState(() {
      _estaCarregando = true;
    });

    try {
      String Nome = _NomeController.text.trim();

      String CPF = _CPFController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

      String RG = _RgController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

      String Tel = _TelController.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

      String Email = _EmailController.text.trim();

      String Data = _dateTime.toString();

      String Senha = _SenhaController.text.trim();

      String confSenha = _ConSenhaController.text.trim();

      if (Nome.isEmpty ||
          CPF.isEmpty ||
          RG.isEmpty ||
          Tel.isEmpty ||
          Email.isEmpty ||
          Data.isEmpty ||
          Senha.isEmpty ||
          confSenha.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Preencha todos os campos.',
            ),
          ),
        );

        setState(() {
          _estaCarregando = false;
        });

        return;
      }

      if (!validarCPF(CPF)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'CPF inválido.',
            ),
          ),
        );

        setState(() {
          _estaCarregando = false;
        });

        return;
      }

      if (!validarTel(Tel)){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Telefone inválido.',
            ),
          ),
        );

        setState(() {
          _estaCarregando = false;
        });

        return;
      }

      if (!validarRG(RG)){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'RG inválido.',
            ),
          ),
        );

        setState(() {
          _estaCarregando = false;
        });

        return;
      }

      if (Senha != confSenha) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'As senhas inseridas não são iguais.',
            ),
          ),
        );

        setState(() {
          _estaCarregando = false;
        });

        return;
      }

      final authResponse = await Supabase.instance.client.auth.signUp(
        email: Email,
        password: Senha,

        data: {
          'prf_tipo': 'cidadao',
          'prf_nome': Nome,
          'cpf': CPF,
          'rg': RG,
          'data_nascimento': Data,
        },
      );

      final user = authResponse.user;

      if (authResponse.session != null) {
        widget.onChangePage(0);
      } else if (authResponse.user != null) {
        widget.onCadastroPendente(Email, Senha);
      }

      print("USER: ${authResponse.user}");
      print("SESSION: ${authResponse.session}");
      print("CURRENT: ${Supabase.instance.client.auth.currentUser}");

      //if (user == null) {
      //  ScaffoldMessenger.of(context).showSnackBar(
      //    const SnackBar(
      //      content: Text(
      //        'Usuário não autenticado.',
      //      ),
      //    ),
      //  );
//
      //  setState(() {
      //    _estaCarregando = false;
      //  });
//
      //  return;
      //}
      //else {
      //  widget.onChangePage(0);
      //}



      _NomeController.clear();
      _CPFController.clear();
      _RgController.clear();
      _TelController.clear();
      _EmailController.clear();
      _SenhaController.clear();
      _ConSenhaController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cadastro Realizado com sucesso!',
          ),
        ),
      );

    } catch (e) {
      print(e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString(),
          ),
        ),
      );
    }

    setState(() {
      _estaCarregando = false;
    });

  }

  void _showDatePicker() {
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1909),
      lastDate: DateTime.now(),
    ).then((value) {
      if (value != null) {
        setState(() {
          _dateTime = value;
        });
      }
    });
  }

  DateTime _dateTime = DateTime(0);

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
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    verticalDirection: VerticalDirection.up,

                    mainAxisSize: MainAxisSize.max,

                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          25,
                          50,
                          25,
                          50,
                        ),
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,

                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),

                            topRight: Radius.circular(30),
                          ),
                        ),

                        child: Column(
                          spacing: 15,

                          children: <Widget>[
                            Text(
                              "Vamos Começar??",

                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: Color.fromRGBO(24, 57, 92, 1),
                              ),
                            ),

                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: _NomeController,

                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Digite seu Nome',
                                ),
                              ),
                            ),

                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: _CPFController,
                                inputFormatters: [cpfMask],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Digite seu CPF',
                                ),
                              ),
                            ),

                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: _RgController,
                                inputFormatters: [rgMask],
                                keyboardType: TextInputType.number,

                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Digite seu RG',
                                ),
                              ),
                            ),

                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: _TelController,
                                inputFormatters: [telMask],
                                keyboardType: TextInputType.number,

                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Número de telefone',
                                ),
                              ),
                            ),

                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: _EmailController,

                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Digite seu E-mail',
                                ),
                              ),
                            ),
                            Text('Insira sua data de nascimento'),
                            Row(
                              spacing: 10,
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: _estaCarregando
                                      ? null
                                      : _showDatePicker,

                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    minimumSize: Size(30, 40),
                                  ),

                                  child: Icon(
                                    Icons.calendar_month,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  width: 250,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey[100],
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.max,

                                    children: [
                                      Text(
                                        "${_dateTime.day}/${_dateTime.month}/${_dateTime.year}",
                                        style: TextStyle(color: Colors.black),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: _SenhaController,

                                obscureText: true,

                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Digite sua senha',
                                ),
                              ),
                            ),

                            SizedBox(
                              width: 350,

                              child: TextField(
                                controller: _ConSenhaController,

                                obscureText: true,

                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),

                                  labelText: 'Confirme sua senha',
                                ),
                              ),
                            ),

                            ElevatedButton(
                              onPressed: _estaCarregando ? null : _enviarDados,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Color.fromRGBO(24, 57, 92, 1),
                                  minimumSize: Size(139, 40)
                              ),

                              child: _estaCarregando
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Enviar',
                                        style: TextStyle(color: Colors.white)
                                    ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.fromLTRB(
                          0,
                          80,
                          0,
                          80,
                        ),

                        child: Image.asset(
                          "gfx/png/Image/SMDN.png",
                          height: 60,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    widget.onChangePage(5);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromRGBO(228, 232, 235, 0.2),
                  ),
                  child: Icon(
                    Icons.arrow_back,
                    size: 15,
                    fontWeight: FontWeight(800),
                    color: Color.fromRGBO(228, 232, 235, 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool validarCPF(String cpf) {
  cpf = cpf.replaceAll(RegExp(r'[^0-9]'), '');
  if (cpf.length != 11) return false;
  if (RegExp(r'^(\d)\1{10}$').hasMatch(cpf)) return false;

  int soma = 0;
  for (int i = 0; i < 9; i++) {
    soma += int.parse(cpf[i]) * (10 - i);
  }
  int resto = soma % 11;
  int digito1 = (resto < 2) ? 0 : 11 - resto;
  if (digito1 != int.parse(cpf[9])) return false;

  soma = 0;
  for (int i = 0; i < 10; i++) {
    soma += int.parse(cpf[i]) * (11 - i);
  }
  resto = soma % 11;
  int digito2 = (resto < 2) ? 0 : 11 - resto;
  if (digito2 != int.parse(cpf[10])) return false;

  return true;
}

bool validarTel (String tel) {
  tel = tel.replaceAll(RegExp(r'[^0-9]'), '');
  if (tel.length < 10 || tel.length > 11) return false;
  return true;
}

bool validarRG (String rg) {
  rg = rg.replaceAll(RegExp(r'[^0-9]'), '');
  if (rg.length < 7 || rg.length > 9) return false;
  return true;
}