import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prever/firebase_options.dart';
import 'package:prever/models/alerta_notificacao.dart';
import 'package:prever/telas/alerta_recebido_tela.dart';
import 'package:prever/models/cidade_alertas.dart';
import 'package:prever/telas/widgets/cidade_alertas_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart'
    show openAppSettings;

@pragma('vm:entry-point')
Future<void> receberPushEmSegundoPlano(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // O payload notification é exibido pelo sistema quando o app está fechado.
  // Não criar outra notificação local aqui, para evitar avisos duplicados.
}

class NotificacoesService with WidgetsBindingObserver {
  NotificacoesService._();
  static final instance = NotificacoesService._();
  static final navigatorKey = GlobalKey<NavigatorState>();
  SharedPreferences? _preferencias;
  static const canal = AndroidNotificationChannel(
    'prever_alertas_urgentes_v1',
    'Alertas Prever',
    description: 'Avisos de risco emitidos pelo painel Prever',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  final _local = FlutterLocalNotificationsPlugin();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  bool _iniciado = false;
  bool _sincronizando = false;
  bool _sincronizarOutraVez = false;
  Timer? _novaTentativa;
  int _tentativas = 0;

  static bool get suportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> iniciar() async {
    if (!suportado || _iniciado) return;
    try {
      _preferencias = await SharedPreferences.getInstance();
      await _local.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_alerta'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) =>
            _abrir(AlertaNotificacao.fromPayload(response.payload)),
      );
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(canal);
      // No iOS o próprio Firebase exibe o banner com o app aberto.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      _subscriptions.add(
        FirebaseMessaging.onMessage.listen((message) {
          unawaited(_mostrarEmPrimeiroPlano(message));
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          _abrir(AlertaNotificacao.fromData(message.data));
        }),
      );
      _subscriptions.add(
        FirebaseMessaging.instance.onTokenRefresh.listen((_) {
          _tentativas = 0;
          unawaited(_sincronizarInscricao());
        }),
      );
      _iniciado = true;
      WidgetsBinding.instance.addObserver(this);
      final localLaunch = await _local.getNotificationAppLaunchDetails();
      if (localLaunch?.didNotificationLaunchApp == true) {
        _abrir(
          AlertaNotificacao.fromPayload(
            localLaunch?.notificationResponse?.payload,
          ),
        );
      }
      final inicial = await FirebaseMessaging.instance.getInitialMessage();
      if (inicial != null) _abrir(AlertaNotificacao.fromData(inicial.data));
      if (!(_preferencias!.getBool('push_cidade_perguntada') ?? false)) {
        await configurarCidade();
      }
      await _sincronizarInscricao();
    } catch (e) {
      debugPrint('Não foi possível iniciar as notificações: ${e.runtimeType}');
      // Falhas de rede/permissão não impedem o uso do aplicativo.
    }
  }

  Future<void> _sincronizarInscricao() async {
    if (_preferencias == null) return;
    if (_sincronizando) {
      _sincronizarOutraVez = true;
      return;
    }
    _sincronizando = true;
    try {
      final messaging = FirebaseMessaging.instance;
      final cidade = _preferencias!.getString('push_cidade') ?? '';
      final topico = cidade.isEmpty ? null : topicoDaCidade(cidade);
      final anterior = _preferencias!.getString('push_topico_inscrito');
      if (anterior != null && anterior != topico) {
        await messaging.unsubscribeFromTopic(anterior);
        await _preferencias!.remove('push_topico_inscrito');
      }
      if (topico == null) return;
      final settings = await messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        throw StateError('Aguardando registro APNs');
      }
      await messaging.subscribeToTopic(topico);
      await _preferencias!.setString('push_topico_inscrito', topico);
      _novaTentativa?.cancel();
      _tentativas = 0;
    } catch (e) {
      debugPrint('Registro push pendente: ${e.runtimeType}');
      if (_tentativas++ < 6) {
        _novaTentativa?.cancel();
        _novaTentativa = Timer(
          Duration(seconds: 10 * _tentativas),
          () => unawaited(_sincronizarInscricao()),
        );
      }
    } finally {
      _sincronizando = false;
      if (_sincronizarOutraVez) {
        _sincronizarOutraVez = false;
        unawaited(_sincronizarInscricao());
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tentativas = 0;
      unawaited(_sincronizarInscricao());
    }
  }

  Future<void> _mostrarEmPrimeiroPlano(RemoteMessage message) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final alerta = AlertaNotificacao.fromData(message.data);
    if (alerta == null || !_daCidadeEscolhida(alerta)) return;
    try {
      await _local.show(
        id: alerta.notificationId,
        title: alerta.titulo,
        body: alerta.descricao,
        payload: alerta.toPayload(),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            canal.id,
            canal.name,
            channelDescription: canal.description,
            importance: Importance.max,
            priority: Priority.high,
            icon: 'ic_stat_alerta',
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
            styleInformation: BigTextStyleInformation(alerta.descricao),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Não foi possível mostrar o aviso: ${e.runtimeType}');
    }
  }

  void _abrir(AlertaNotificacao? alerta) {
    if (alerta == null || !_daCidadeEscolhida(alerta)) return;
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => AlertaRecebidoTela(alerta: alerta),
      ),
    );
  }

  Future<void> configurarCidade() async {
    try {
      await _configurarCidade();
    } catch (e) {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível ativar os avisos agora. Tente novamente em Cidade dos alertas.',
            ),
          ),
        );
      }
    }
  }

  bool _daCidadeEscolhida(AlertaNotificacao alerta) {
    final cidade = _preferencias?.getString('push_cidade');
    if (cidade == null || cidade.isEmpty) return false;
    try {
      return topicoDaCidade(alerta.cidade) == topicoDaCidade(cidade);
    } on FormatException {
      return false;
    }
  }

  Future<void> _configurarCidade() async {
    if (!suportado) return;
    _preferencias ??= await SharedPreferences.getInstance();
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    await _preferencias!.setBool('push_cidade_perguntada', true);
    if (!context.mounted) return;
    final cidade = await showDialog<String>(
      context: context,
      builder: (_) => CidadeAlertasDialog(
        cidade: _preferencias!.getString('push_cidade') ?? '',
      ),
    );
    if (cidade == null) return;
    await _preferencias!.setString('push_cidade', cidade);
    if (cidade.isNotEmpty) {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied &&
          context.mounted) {
        await _sincronizarInscricao();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Permita as notificações do Prever nas configurações do celular.',
            ),
            action: SnackBarAction(
              label: 'Configurações',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        return;
      }
    }
    _tentativas = 0;
    await _sincronizarInscricao();
    if (!context.mounted) return;
    final inscrito = _preferencias!.getString('push_topico_inscrito');
    final concluido = cidade.isEmpty
        ? inscrito == null
        : inscrito == topicoDaCidade(cidade);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          !concluido
              ? 'Preferência salva. Aguardando conexão para atualizar os alertas.'
              : cidade.isEmpty
              ? 'Alertas desativados neste aparelho.'
              : 'Alertas ativados para $cidade.',
        ),
      ),
    );
  }
}
