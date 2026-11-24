import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Deve executar após Firebase.initializeApp e antes das chamadas ao Nimbo.
Future<void> configurarAppCheckMobile() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return;
  }
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );
  // Somente o SDK nativo registra o segredo de desenvolvimento no log local.
  // Nunca inclua esse segredo no código, nos relatos ou em builds de produção.
  if (kDebugMode) unawaited(_verificarCadastroDeTeste());
}

Future<void> _verificarCadastroDeTeste() async {
  try {
    final token = await FirebaseAppCheck.instance.getToken();
    if (token != null && token.isNotEmpty) {
      debugPrint('App Check: dispositivo de teste autorizado.');
    } else {
      debugPrint('App Check: token de teste ainda indisponível.');
    }
  } catch (_) {
    // Não impede mapa, login ou push durante o cadastro no console.
    debugPrint(
      'App Check: verifique o cadastro do token de depuração no Firebase.',
    );
  }
}
