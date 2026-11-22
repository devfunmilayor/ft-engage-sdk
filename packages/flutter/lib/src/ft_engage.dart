import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ft_engage_core/ft_engage_core.dart';

import 'hive_storage.dart';
import 'push_source.dart';

class FtEngage with WidgetsBindingObserver {
  FtEngage._(this.client, this._pushSource, this._platform, this._appVersion);

  final EngageClient client;
  final PushSource? _pushSource;
  final String? _platform;
  final String? _appVersion;
  PushState? _lastPush;
  bool _observing = false;

  static Future<FtEngage> init({
    required String publicKey,
    required Uri endpoint,
    bool requireConsent = false,
    String? appVersion,
    PushSource? pushSource,
    Transport? transport,
    EngageStorage? storage,
    Duration? flushInterval = const Duration(seconds: 30),
    bool observeLifecycle = true,
    String? platformOverride,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final client = await EngageClient.create(
      config: EngageConfig(
        publicKey: publicKey,
        endpoint: endpoint,
        requireConsent: requireConsent,
        flushInterval: flushInterval,
        appVersion: appVersion,
      ),
      transport: transport ?? HttpTransport(),
      storage: storage ?? await HiveStorage.open(),
    );
    final instance = FtEngage._(
      client,
      pushSource,
      platformOverride ?? _detectPlatform(),
      appVersion,
    );
    if (observeLifecycle) instance._startObserving();
    await instance._syncRegistration();
    await client.track('app.opened');
    return instance;
  }

  static String? _detectPlatform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
  }

  void _startObserving() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> track(
    String name, {
    Map<String, Object?> props = const {},
    String? screen,
  }) => client.track(name, props: props, screen: screen);

  Future<void> identify(
    String userId, {
    String? email,
    String? phone,
    Map<String, Object?> traits = const {},
    Map<MarketingChannel, bool> marketingConsent = const {},
  }) => client.identify(
    userId,
    email: email,
    phone: phone,
    traits: traits,
    marketingConsent: marketingConsent,
  );

  Future<void> logout() => client.logout();

  Future<void> setConsent(ConsentState state) async {
    await client.setConsent(state);
    if (state == ConsentState.granted) await _syncRegistration(force: true);
  }

  Future<FlushResult> flush() => client.flush(force: true);

  Future<void> forget() async {
    _lastPush = null;
    await client.forget();
  }

  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    client.close();
  }

  Future<void> _syncRegistration({bool force = false}) async {
    final platform = _platform;
    if (platform == null) return;
    final push = await _pushSource?.read() ?? PushState.unknown;
    if (!force && push == _lastPush) return;
    _lastPush = push;
    await client.register(
      RegisterInfo(
        platform: platform,
        appVersion: _appVersion,
        timezone: DateTime.now().timeZoneName,
        locale: PlatformDispatcher.instance.locale.toLanguageTag(),
        pushStatus: push.status,
        pushToken: push.token,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        client.track('app.foregrounded');
        _syncRegistration();
      case AppLifecycleState.paused:
        client.track('app.backgrounded').then((_) => client.flush(force: true));
      default:
        break;
    }
  }
}
