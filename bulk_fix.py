import os
import glob
import re

def process_file(path, replacements):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    original = content
    for pattern, repl in replacements:
        content = re.sub(pattern, repl, content)
    if content != original:
        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Modified {path}")

# 1. Fix main.dart (Supabase credentials)
main_replacements = [
    (r"url: 'https://robfgvtnoooivihlnomr\.supabase\.co',", r"url: dotenv.env['SUPABASE_URL'] ?? 'https://robfgvtnoooivihlnomr.supabase.co',"),
    (r"anonKey: 'sb_publishable_eVCeoqzfhoAgkpBnJxzs7w_-PGO0TO9',", r"anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? 'sb_publishable_eVCeoqzfhoAgkpBnJxzs7w_-PGO0TO9',"),
    (r"import 'package:branch1/telas/discarded/discarded_home.dart';", ""),
    (r"await Supabase\.initialize\((.*?)\);\s*await dotenv\.load\(fileName: \"\.env\"\);", r"await dotenv.load(fileName: \".env\");\n\n  await Supabase.initialize(\1);")
]
process_file('lib/main.dart', main_replacements)

# 2. Fix cadastro_tela.dart
cadastro_replacements = [
    (r"import 'package:branch1/telas/cadastro_tela\.dart';\n", ""),
    (r"DateTime _dateTime = DateTime\(0\);", r"DateTime _dateTime = DateTime.now();\n  bool _validarEmail(String email) {\n    final regexEmail = RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');\n    return regexEmail.hasMatch(email);\n  }"),
    (r"String Nome = _NomeController\.text\.trim\(\);", r"String nome = _NomeController.text.trim();"),
    (r"String CPF = _CPFController", r"String cpf = _CPFController"),
    (r"String RG = _RgController", r"String rg = _RgController"),
    (r"String Tel = _TelController", r"String tel = _TelController"),
    (r"String Email = _EmailController", r"String email = _EmailController"),
    (r"String Data = _dateTime", r"String data = _dateTime"),
    (r"String Senha = _SenhaController", r"String senha = _SenhaController"),
    (r"Nome\.isEmpty", r"nome.isEmpty"),
    (r"CPF\.isEmpty", r"cpf.isEmpty"),
    (r"RG\.isEmpty", r"rg.isEmpty"),
    (r"Tel\.isEmpty", r"tel.isEmpty"),
    (r"Email\.isEmpty", r"email.isEmpty"),
    (r"Data\.isEmpty", r"!pickedDate"),
    (r"Senha\.isEmpty", r"senha.isEmpty"),
    (r"validarCPF\(CPF\)", r"validarCPF(cpf)"),
    (r"validarTel\(Tel\)", r"validarTel(tel)"),
    (r"validarRG\(RG\)", r"validarRG(rg)"),
    (r"Senha != confSenha", r"senha.length < 6) {\n        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A senha deve ter pelo menos 6 caracteres.')));\n        setState(() { _estaCarregando = false; });\n        return;\n      }\n\n      if (senha != confSenha"),
    (r"password: Senha,", r"password: senha,"),
    (r"email: Email,", r"email: email,"),
    (r"'prf_nome': Nome,", r"'prf_nome': nome,"),
    (r"'cpf': CPF,", r"'cpf': cpf,"),
    (r"'rg': RG,", r"'rg': rg,"),
    (r"'data_nascimento': Data,", r"'data_nascimento': data,"),
    (r"final user = authResponse\.user;\n", ""),
    (r"widget\.onCadastroPendente\(Email, Senha\);", r"widget.onCadastroPendente(email, senha);"),
    (r"print\(\"USER: \$\{authResponse\.user\}\"\);\n\s*print\(\"SESSION: \$\{authResponse\.session\}\"\);\n\s*print\(\"CURRENT: \$\{Supabase\.instance\.client\.auth\.currentUser\}\"\);", r"debugPrint('=== CADASTRO: signUp concluído ===');"),
    (r"print\(e\);\n\s*ScaffoldMessenger\.of\(context\)\.showSnackBar\(\n\s*SnackBar\(\n\s*content: Text\(\n\s*e\.toString\(\),\n\s*\),\n\s*\),\n\s*\);", r"debugPrint('Erro: $e'); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro no cadastro.')));")
]
process_file('lib/telas/cadastro_tela.dart', cadastro_replacements)

# 3. Rename classes using the correct script
class_replacements = [
    (r"\bsLogCad\b", "SLogCad"), 
    (r"\b_sLogCad_State\b", "_SLogCadState"), 
    (r"\bconfEmail\b", "ConfEmail"), 
    (r"\b_confEmailState\b", "_ConfEmailState"), 
    (r"\bchangePassword\b", "ChangePassword"), 
    (r"\b_changePasswordState\b", "_ChangePasswordState"), 
    (r"\bwriteChangedPassword\b", "WriteChangedPassword"), 
    (r"\b_writeChangedPasswordState\b", "_WriteChangedPasswordState"), 
    (r"\bsLogin\b", "SLogin"), 
    (r"\b_sLogin_State\b", "_SLoginState"),
    (r"package:branch1", "package:prever")
]
for f in glob.glob('lib/**/*.dart', recursive=True):
    process_file(f, class_replacements)

# 4. default_widgets.dart
dw_replacements = [
    (r"Function\(\) FecharPinVisao;", r"final Function() FecharPinVisao;"),
    (r"String pinID;", r"final String pinID;"),
    (r"PinsVisao\({", r"const PinsVisao({super.key,"),
    (r"AlignmentGeometry\.lerp\(\s*AlignmentGeometry\.lerp\(Alignment\.topCenter, null, 0\),\s*null,\s*0\)!", r"Alignment.topCenter"),
    (r"AlignmentGeometry\.lerp\(\s*AlignmentGeometry\.lerp\(Alignment\.centerLeft, null, 0\),\s*null,\s*0\)!", r"Alignment.centerLeft")
]
process_file('lib/telas/formatadores/default_widgets.dart', dw_replacements)
