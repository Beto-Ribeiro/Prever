import 'package:flutter/material.dart';

class AccessibilityController extends ChangeNotifier {
  bool daltonismo = false;
  bool letrasGrandes = false;
  bool altoContraste = false;

  void toggleDaltonismo() {
    daltonismo = !daltonismo;
    notifyListeners();
  }

  void toggleLetrasGrandes() {
    letrasGrandes = !letrasGrandes;
    notifyListeners();
  }

  void toggleAltoContraste() {
    altoContraste = !altoContraste;
    notifyListeners();
  }

  double get escalaFonte {
    return letrasGrandes ? 1.4 : 1.0;
  }

  Color get corPrimaria {
    if (altoContraste) {
      return Colors.yellow;
    }

    if (daltonismo) {
      return Color(0xFF6A4C93);
    }

    return Color(0xFF1D3557);
  }

  Color get corSecundaria {
    if (altoContraste) {
      return Colors.white;
    }

    if (daltonismo) {
      return Color(0xFFF4A261);
    }

    return Color(0xFF8FB3D9);
  }

  Color get fundo {
    return altoContraste ? Colors.black : Color(0xFFF5F7FA);
  }
}
