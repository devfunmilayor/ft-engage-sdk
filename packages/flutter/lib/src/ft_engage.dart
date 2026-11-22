import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ft_engage_core/ft_engage_core.dart';

import 'hive_storage.dart';
import 'insights/engage_navigator_observer.dart';
import 'insights/replay_recorder.dart';
import 'push_source.dart';

class FtEngage with WidgetsBindingObserver {
  FtEngage._(
    this.client,
    this._pushSource,
    this._platform,
    this._appVersion,
    this.insights,
    this.replay,
  );

  final EngageClient client;
  final InsightsRecorder? insights;
  final ReplayRecorder? replay;
  int navigationEpoch = 0;
  late final NavigatorObserver navigatorObserver = EngageNavigatorObserver(
    this,
  );
  final PushSource? _pushSource;
  final String? _platform;
  final String? _appVersion;
  PushState? _lastPush;
  StreamSubscription<void>? _pushChanges;
  bool _observing = false;

  static Future<FtEngage> init({
    required String publicKey,
    required Uri endpoint,
    bool requireConsent = false,
    String? appVersion,
    String? appId,
    PushSource? pushSource,
    Transport? transport,
    EngageStorage? storage,
    Duration? flushInterval = const Duration(seconds: 30),
    bool observeLifecycle = true,
    String? platformOverride,
    InsightsConfig? insights,
    ReplayConfig? replay,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();
    final store = storage ?? await HiveStorage.open();
    final client = await EngageClient.create(
      config: EngageConfig(
        publicKey: publicKey,
        endpoint: endpoint,
        requireConsent: requireConsent,
        flushInterval: flushInterval,
        appVersion: appVersion,
        appId: appId,
      ),
      transport: transport ?? HttpTransport(),
      storage: store,
    );
    final platform = platformOverride ?? _detectPlatform();
    final recorder = replay == null
        ? null
        : ReplayRecorder(
            buffer: ReplayBuffer(
              config: replay,
              send: client.postReplay,
              installId: () => client.installId,
              platform: platform,
            ),
          );
    final insightsConfig =
        insights ?? (replay == null ? null : const InsightsConfig());
    final instance = FtEngage._(
      client,
      pushSource,
      platform,
      appVersion,
      insightsConfig == null
          ? null
          : InsightsRecorder(
              config: insightsConfig,
              track: client.track,
              storage: store,
              listener: recorder,
            ),
      recorder,
    );
    await instance.insights?.recover();
    if (observeLifecycle) instance._startObserving();
    if (pushSource is PushChanges) {
      instance._pushChanges = (pushSource as PushChanges).changes.listen(
        (_) => unawaited(instance._syncRegistration()),
        onError: (Object _) {},
      );
    }
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

  void screen(String name) => insights?.screenViewed(name);

  Future<void> identify(
    String userId, {
    String? userHash,
    String? email,
    String? phone,
    Map<String, Object?> traits = const {},
    Map<MarketingChannel, bool> marketingConsent = const {},
  }) => client.identify(
    userId,
    userHash: userHash,
    email: email,
    phone: phone,
    traits: traits,
    marketingConsent: marketingConsent,
  );

  Future<void> logout() => client.logout();

  Future<void> setConsent(ConsentState state) async {
    await client.setConsent(state);
    if (state == ConsentState.denied) replay?.buffer.clear();
    if (state == ConsentState.granted) await _syncRegistration(force: true);
  }

  Future<PushState> requestPushPermission() async {
    final Object? source = _pushSource;
    if (source is! PushPermission) return _lastPush ?? PushState.unknown;
    final state = await source.request();
    await _syncRegistration(force: true);
    return state;
  }

  Future<FlushResult> flush() => client.flush(force: true);

  Future<void> forget() async {
    _lastPush = null;
    replay?.buffer.clear();
    await client.forget();
  }

  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _observing = false;
    unawaited(_pushChanges?.cancel());
    _pushChanges = null;
    replay?.dispose();
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
        replay?.mark('fg');
        client.track('app.foregrounded');
        _syncRegistration();
      case AppLifecycleState.paused:
        insights?.leaveScreen();
        replay?.mark('bg');
        unawaited(replay?.buffer.flush() ?? Future<void>.value());
        client.track('app.backgrounded').then((_) => client.flush(force: true));
      default:
        break;
    }
  }
}
