import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alerta_geografico.dart';

/// Registra apenas posições obtidas enquanto o aplicativo está em uso.
/// O servidor filtra o raio e descarta localizações com mais de 30 minutos.
/// Em segundo plano o sistema operacional apresenta o payload notification FCM.
class AlertasNotificacaoService with WidgetsBindingObserver {
  AlertasNotificacaoService._();

  static final instance = AlertasNotificacaoService._();
  static const canalId = 'alertas_web_v2';
  static final _vibracao = Int64List.fromList([0, 800, 300, 800, 300, 800]);

  Future<void> _configurarCanal() async {
    final android = _notificacoes
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    final canais = await android.getNotificationChannels();
    AndroidNotificationChannel? anterior;
    for (final canal in canais ?? <AndroidNotificationChannel>[]) {
      if (canal.id == canalId)
        return; // Preserva ajustes posteriores do usuário.
      if (canal.id == 'alertas_web') anterior = canal;
    }
    // Um canal existente não aceita outro padrão. Migra as preferências,
    // inclusive canal bloqueado ou silenciado, sem remover o canal antigo.
    final vibrar = anterior?.enableVibration ?? true;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        canalId,
        'Alertas próximos',
        description: 'Alertas a até 20 km, com três pulsos de vibração.',
        importance: anterior?.importance ?? Importance.high,
        playSound: anterior?.playSound ?? true,
        sound: anterior?.sound,
        enableVibration: vibrar,
        vibrationPattern: vibrar ? _vibracao : null,
        showBadge: anterior?.showBadge ?? true,
        enableLights: anterior?.enableLights ?? false,
        ledColor: anterior?.ledColor,
        groupId: anterior?.groupId,
        audioAttributesUsage:
            anterior?.audioAttributesUsage ?? AudioAttributesUsage.notification,
      ),
    );
  }

  final _notificacoes = FlutterLocalNotificationsPlugin();
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  SupabaseClient get _supabase => Supabase.instance.client;

  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openSubscription;
  Timer? _timer;
  Timer? _tentativaInicializacao;
  SharedPreferences? _preferencias;
  Future<void> _fila = Future<void>.value();
  Future<void>? _inicializacao;
  VoidCallback? _abrirMapa;
  String? _usuario;
  String? _token;
  String? _donoToken;
  int _geracao = 0;
  bool _iniciado = false;
  bool _pronto = false;
  bool _emPrimeiroPlano = true;
  bool _saindo = false;
  bool _pediuNotificacao = false;
  bool _rotacaoPendente = false;

  bool get _plataformaSuportada =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> iniciar({required VoidCallback abrirMapa}) async {
    if (!_plataformaSuportada) return;
    _abrirMapa = abrirMapa;
    if (_iniciado) {
      await _inicializacao;
      return;
    }
    _iniciado = true;
    _inicializacao = _configurar();
    await _inicializacao;
  }

  Future<void> _configurar() async {
    try {
      _preferencias = await SharedPreferences.getInstance();
      _donoToken = _preferencias?.getString('alertas_dono_token');
      _token = _preferencias?.getString('alertas_token');
      _rotacaoPendente =
          _preferencias?.getBool('alertas_rotacionar_token') ?? false;
      await _notificacoes.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_alerta'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (resposta) {
          if (resposta.payload?.startsWith('alerta_web:') == true) {
            _navegarParaMapa();
          }
        },
      );
      await _configurarCanal();
      // Também no iOS a apresentação em foreground passa pelo filtro GPS.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      if (!_iniciado) return;
      _pronto = true;
      _usuario = _supabase.auth.currentUser?.id;
      _emPrimeiroPlano =
          WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
      WidgetsBinding.instance.addObserver(this);
      _authSubscription = _supabase.auth.onAuthStateChange.listen((estado) {
        final usuario = estado.session?.user.id;
        if (usuario == _usuario) return;
        final anterior = _usuario;
        _usuario = usuario;
        _geracao++;
        _saindo = false;
        _pararLocalizacao();
        unawaited(
          _agendar(() async {
            // Não reutiliza o token associado à conta anterior.
            if (anterior != null || usuario == null) await _excluirToken();
            await _sincronizar();
          }),
        );
      }, onError: (Object _) => _registrarFalha());
      _tokenSubscription = _messaging.onTokenRefresh.listen((novoToken) {
        if (_saindo || !_iniciado) return;
        final antigo = _token;
        _token = novoToken;
        unawaited(
          _agendar(() async {
            if (antigo != null && antigo != novoToken) {
              await _desativarToken(antigo);
            }
            await _sincronizar();
          }),
        );
      }, onError: (Object _) => _registrarFalha());
      _messageSubscription = FirebaseMessaging.onMessage.listen((mensagem) {
        unawaited(_agendar(() => _mostrarEmPrimeiroPlano(mensagem)));
      });
      _openSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
        mensagem,
      ) {
        if (AlertaGeografico.deMensagem(mensagem.data) != null) {
          _navegarParaMapa();
        }
      });
      _timer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (_emPrimeiroPlano && _usuario != null) {
          unawaited(_agendar(_sincronizar));
        }
      });

      final mensagemInicial = await _messaging.getInitialMessage();
      if (mensagemInicial != null &&
          AlertaGeografico.deMensagem(mensagemInicial.data) != null) {
        _navegarParaMapa();
      }
      final aberturaLocal = await _notificacoes
          .getNotificationAppLaunchDetails();
      if (aberturaLocal?.didNotificationLaunchApp == true &&
          aberturaLocal?.notificationResponse?.payload?.startsWith(
                'alerta_web:',
              ) ==
              true) {
        _navegarParaMapa();
      }
      await _agendar(() async {
        if (_usuario == null) await _excluirToken();
        await _sincronizar();
      });
    } catch (_) {
      // Falha de push não impede o uso de mapa, relatos ou autenticação.
      _registrarFalha();
      _pronto = false;
      WidgetsBinding.instance.removeObserver(this);
      await _cancelarAssinaturas();
      if (_iniciado) {
        _tentativaInicializacao?.cancel();
        _tentativaInicializacao = Timer(const Duration(seconds: 30), () {
          if (_iniciado) _inicializacao = _configurar();
        });
      }
    }
  }

  Future<void> _agendar(Future<void> Function() acao) {
    _fila = _fila.then((_) async {
      try {
        await acao();
      } catch (_) {
        _registrarFalha();
      }
    });
    return _fila;
  }

  void _registrarFalha() => debugPrint(
    'Alertas: atualização indisponível. Será tentada novamente ao retomar o app.',
  );

  bool _sessaoValida(int geracao, String? usuario) =>
      _iniciado &&
      _pronto &&
      !_saindo &&
      _emPrimeiroPlano &&
      usuario != null &&
      geracao == _geracao &&
      usuario == _supabase.auth.currentUser?.id;

  Future<bool> _temLocalizacao() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permissao = await Geolocator.checkPermission();
    return permissao == LocationPermission.whileInUse ||
        permissao == LocationPermission.always;
  }

  Future<bool> _temNotificacoes({bool solicitar = false}) async {
    var configuracao = await _messaging.getNotificationSettings();
    if (solicitar && !_pediuNotificacao) {
      _pediuNotificacao = true;
      configuracao = await _messaging.requestPermission();
    }
    return configuracao.authorizationStatus == AuthorizationStatus.authorized ||
        configuracao.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<Position> _posicaoAtual() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 15),
    ),
  );

  bool _posicaoRecente(Position posicao) {
    final idade = DateTime.now().difference(posicao.timestamp);
    return idade >= const Duration(seconds: -30) &&
        idade <= const Duration(minutes: 2) &&
        coordenadasValidas(posicao.latitude, posicao.longitude);
  }

  Future<void> _sincronizar() async {
    final geracao = _geracao;
    final usuario = _usuario;
    if (!_sessaoValida(geracao, usuario)) return;
    // Persistido: também cobre troca de conta após reiniciar ou sair offline.
    if (_rotacaoPendente || (_donoToken != null && _donoToken != usuario)) {
      if (!await _excluirToken()) return;
    }
    if (!_sessaoValida(geracao, usuario)) return;
    if (!await _temLocalizacao() || !await _temNotificacoes(solicitar: true)) {
      _pararLocalizacao();
      await _desativarToken(_token);
      return;
    }
    if (!_sessaoValida(geracao, usuario)) return;
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _messaging.getAPNSToken() == null) {
      // O token APNs pode chegar depois do primeiro frame. Retoma/timer repete.
      return;
    }
    final tokenAtual = await _messaging.getToken();
    if (!_sessaoValida(geracao, usuario)) return;
    if (_token != null && tokenAtual != _token) await _desativarToken(_token);
    _token = tokenAtual;
    if (_token == null || !_sessaoValida(geracao, usuario)) return;
    final posicao = await _posicaoAtual();
    await _registrarPosicao(posicao, geracao, usuario);
    if (!_sessaoValida(geracao, usuario) || _positionSubscription != null) {
      return;
    }
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 100,
          ),
        ).listen(
          (posicao) {
            unawaited(
              _agendar(() => _registrarPosicao(posicao, geracao, usuario)),
            );
          },
          onError: (Object _) {
            if (!_sessaoValida(geracao, usuario)) return;
            final token = _token;
            _pararLocalizacao();
            unawaited(
              _agendar(() async {
                if (_sessaoValida(geracao, usuario))
                  await _desativarToken(token);
              }),
            );
          },
        );
  }

  Future<void> _registrarPosicao(
    Position posicao,
    int geracao,
    String? usuario,
  ) async {
    if (!_sessaoValida(geracao, usuario) ||
        !_posicaoRecente(posicao) ||
        _token == null) {
      return;
    }
    if (!await _temNotificacoes() || !await _temLocalizacao()) {
      _pararLocalizacao();
      await _desativarToken(_token);
      return;
    }
    if (!_sessaoValida(geracao, usuario)) return;
    // Persiste antes da RPC: mesmo que o app feche após a resposta do servidor,
    // a próxima conta saberá que precisa obter um token novo.
    _donoToken = usuario;
    await _preferencias?.setString('alertas_dono_token', usuario!);
    await _preferencias?.setString('alertas_token', _token!);
    if (!_sessaoValida(geracao, usuario)) return;
    await _supabase
        .rpc(
          'registrar_dispositivo_alerta',
          params: {
            'p_token': _token,
            'p_latitude': posicao.latitude,
            'p_longitude': posicao.longitude,
            'p_plataforma': defaultTargetPlatform == TargetPlatform.android
                ? 'android'
                : 'ios',
          },
        )
        .timeout(const Duration(seconds: 15));
  }

  Future<void> _mostrarEmPrimeiroPlano(RemoteMessage mensagem) async {
    final alerta = AlertaGeografico.deMensagem(mensagem.data);
    final geracao = _geracao;
    final usuario = _usuario;
    if (alerta == null || !_sessaoValida(geracao, usuario)) return;
    if (!await _temNotificacoes() || !await _temLocalizacao()) return;
    final chave = 'alertas_exibidos_$usuario';
    final exibidos = _preferencias?.getStringList(chave) ?? <String>[];
    if (exibidos.contains(alerta.id)) return;
    final posicao = await _posicaoAtual();
    if (!_sessaoValida(geracao, usuario) ||
        !_posicaoRecente(posicao) ||
        !estaNoRaioDoAlerta(
          posicao.latitude,
          posicao.longitude,
          alerta.latitude,
          alerta.longitude,
        )) {
      return;
    }
    await _notificacoes.show(
      id: _idNotificacao(alerta.id),
      title: alerta.titulo,
      body: alerta.descricao,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canalId,
          'Alertas próximos',
          channelDescription: 'Alertas a até 20 km da sua localização recente.',
          icon: 'ic_stat_alerta',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: _vibracao,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: 'alerta_web:${alerta.id}',
    );
    exibidos.add(alerta.id);
    if (exibidos.length > 200) exibidos.removeRange(0, exibidos.length - 200);
    await _preferencias?.setStringList(chave, exibidos);
  }

  int _idNotificacao(String id) {
    var hash = 0;
    for (final unidade in id.codeUnits) {
      hash = (hash * 31 + unidade) & 0x7fffffff;
    }
    return hash;
  }

  void _navegarParaMapa() {
    if (!_iniciado || _saindo || _supabase.auth.currentUser == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_iniciado && !_saindo && _supabase.auth.currentUser != null) {
        _abrirMapa?.call();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _pararLocalizacao() {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  Future<void> _desativarToken(String? token) async {
    if (token == null || _supabase.auth.currentUser == null) return;
    try {
      await _supabase
          .rpc(
            'desativar_dispositivo_alerta',
            params: {
              'p_token': token,
            },
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      _registrarFalha();
    }
  }

  Future<bool> _excluirToken() async {
    _rotacaoPendente = true;
    try {
      await _preferencias?.setBool('alertas_rotacionar_token', true);
      await _messaging.deleteToken().timeout(const Duration(seconds: 10));
      await _preferencias?.remove('alertas_dono_token');
      await _preferencias?.remove('alertas_token');
      await _preferencias?.setBool('alertas_rotacionar_token', false);
      _token = null;
      _donoToken = null;
      _rotacaoPendente = false;
      return true;
    } catch (_) {
      _registrarFalha();
      return false;
    }
  }

  /// Deve ser aguardado ANTES de Supabase.auth.signOut(), ainda autenticado.
  Future<void> prepararSaida() async {
    if (!_plataformaSuportada || !_iniciado) return;
    _saindo = true;
    _geracao++;
    _pararLocalizacao();
    await _agendar(() async {
      await _desativarToken(_token);
      await _excluirToken();
      await _notificacoes.cancelAll();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _emPrimeiroPlano = state == AppLifecycleState.resumed;
    _geracao++;
    _pararLocalizacao();
    if (_emPrimeiroPlano) unawaited(_agendar(_sincronizar));
  }

  Future<void> dispose() async {
    _iniciado = false;
    _pronto = false;
    _geracao++;
    _abrirMapa = null;
    _tentativaInicializacao?.cancel();
    _tentativaInicializacao = null;
    WidgetsBinding.instance.removeObserver(this);
    await _cancelarAssinaturas();
  }

  Future<void> _cancelarAssinaturas() async {
    _timer?.cancel();
    _timer = null;
    _pararLocalizacao();
    await _authSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openSubscription?.cancel();
    _authSubscription = null;
    _tokenSubscription = null;
    _messageSubscription = null;
    _openSubscription = null;
  }
}
