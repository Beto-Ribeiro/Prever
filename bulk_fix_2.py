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

# editar_perfil_tela.dart
process_file('lib/telas/editar_perfil_tela.dart', [
    (r"initialValue: _tipoSanguineoSelecionado", r"value: _tipoSanguineoSelecionado")
])

# chatbot_tela.dart
process_file('lib/telas/chatbot_tela.dart', [
    (r"errorBuilder: \(_, _, _\) => _NimboFallback", r"errorBuilder: (context, error, stackTrace) => _NimboFallback"),
    (r"builder: \(_, _\) \{", r"builder: (context, child) {")
])

# login_tela.dart
process_file('lib/telas/login_tela.dart', [
    (r"backgroundColor: Color\.fromRGBO\(228, 232, 235, 0\.2\),", r"backgroundColor: Color.fromRGBO(24, 57, 92, 1),"),
    (r"final email = _EmailController\.text\.trim\(\);", r"final email = _EmailController.text.trim();\n      final regexEmail = RegExp(r'^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');\n      if (!regexEmail.hasMatch(email)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E-mail inválido.'))); return; }")
])

# perfil.dart
process_file('lib/telas/perfil.dart', [
    (r"\} catch \(e\) \{\}", r"} catch (e) { debugPrint('Erro silencioso: $e'); }")
])

# tela_principal.dart
process_file('lib/telas/tela_principal.dart', [
    (r"Future<void> _Ask_for_permission\(\) async", r"Future<void> _pedirPermissao() async"),
    (r"_Ask_for_permission\(\);", r"_pedirPermissao();"),
    (r"icones\[\s*currentIndex\],", r"icones[currentIndex < icones.length ? currentIndex : 0],")
])

# Home.dart
process_file('lib/telas/Home.dart', [
    (r"Future<void> _Ask_for_permission\(\) async \{.*?\n\}", r"", re.DOTALL),
    (r"await _Ask_for_permission\(\);", r""),
    (r"final String tresPrimeirosDigitos = cpfCompleto\.substring\(0, 3\);\n\s*if \(tresPrimeirosDigitos == cpfDigitado\) \{", r"final String cpfLimpo = cpfCompleto.replaceAll(RegExp(r'[^0-9]'), '');\n    if (cpfLimpo == cpfDigitado) {"),
    (r"maxLength: 3,", r"maxLength: 14,"),
    (r"dígitos do seu CPF", r"seu CPF"),
    (r"ValidarCPF\(\);", r"await ValidarCPF();"),
    (r"onPressed: \(\) \{", r"onPressed: () async {")
])

# maps_alertas.dart
process_file('lib/telas/maps_alertas.dart', [
    (r"String SelectedMarkerId", r"String _selectedMarkerId"),
    (r"SelectedMarkerId = ID", r"_selectedMarkerId = ID"),
    (r"pinID: SelectedMarkerId", r"pinID: _selectedMarkerId"),
    (r"const Duration\(seconds: 10\)", r"const Duration(minutes: 1)")
])
