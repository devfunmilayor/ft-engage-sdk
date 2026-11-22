import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'clock.dart';
import 'config.dart';
import 'consent.dart';
import 'identity.dart';
import 'identity_payload.dart';
import 'property_guard.dart';
import 'queue.dart';
import 'replay.dart';
import 'storage.dart';
import 'transport.dart';

class RegisterInfo {
  const RegisterInfo({
    required this.platform,
    this.appVersion,
    this.timezone,
    this.locale,
    this.pushStatus = 'unknown',
    this.pushToken,
  });

  final String platform;
  final String? appVersion;
  final String? timezone;
  final String? locale;
  final String pushStatus;
  final String? pushToken;
}

class FlushResult {
  const FlushResult({
    this.sent = 0,
    this.dropped = 0,
    this.pending = 0,
    this.retryAt,
    this.lastStatus,
  });

  final int sent;
  final int dropped;
  final int pending;
  final DateTime? retryAt;
  final int? lastStatus;
}

class EngageClient {
  EngageClient._(
    this.config,
    this._store,
    this._transport,
    this._clock,
    this._ids,
    this._queue,
    this._installId,
    this._userId,
    this._consent,
    this._pendingRegister,
    this._pendingIdentify,
  );

  static const _installKey = 'ft_engage.install_id';
  static const _userKey = 'ft_engage.user_id';
  static const _consentKey = 'ft_engage.consent';
  static const _registerKey = 'ft_engage.register';
  static const _identifyKey = 'ft_engage.identify';
  static const _baseBackoff = Duration(seconds: 5);
  static const _maxBackoff = Duration(minutes: 5);

  final EngageConfig config;
  final EngageStorage _store;
  final Transport _transport;
  final Clock _clock;
  final IdGenerator _ids;
  final EventQueue _queue;
  String _installId;
  String? _userId;
  ConsentState _consent;
  Map<String, Object?>? _pendingRegister;
  Map<String, Object?>? _pendingIdentify;
  int _failures = 0;
  DateTime? _retryAt;
  Future<FlushResult>? _flushing;
  bool _flushingFullOnly = false;
  Timer? _timer;

  static Future<EngageClient> create({
    required EngageConfig config,
    required Transport transport,
    EngageStorage? storage,
    Clock clock = const SystemClock(),
    IdGenerator? ids,
  }) async {
    final kv = storage ?? MemoryStore();
    final generator = ids ?? RandomIdGenerator();
    var installId = await kv.read(_installKey);
    if (installId == null) {
      installId = generator.install();
      await kv.write(_installKey, installId);
    }
    final queue = EventQueue(kv, config.maxQueueSize);
    await queue.load();
    final consentName = await kv.read(_consentKey);
    final consent = ConsentState.values.firstWhere(
      (state) => state.name == consentName,
      orElse: () => ConsentState.unknown,
    );
    final rawRegister = await kv.read(_registerKey);
    final rawIdentify = await kv.read(_identifyKey);
    final client = EngageClient._(
      config,
      kv,
      transport,
      clock,
      generator,
      queue,
      installId,
      await kv.read(_userKey),
      consent,
      rawRegister == null
          ? null
          : Map<String, Object?>.from(jsonDecode(rawRegister) as Map),
      rawIdentify == null
          ? null
          : Map<String, Object?>.from(jsonDecode(rawIdentify) as Map),
    );
    final interval = config.flushInterval;
    if (interval != null) {
      client._timer = Timer.periodic(
        interval,
        (_) => unawaited(client.flush()),
      );
    }
    return client;
  }

  String get installId => _installId;
  String? get userId => _userId;
  ConsentState get consent => _consent;
  int get pendingCount => _queue.length;
  bool get canCollect =>
      !config.requireConsent || _consent == ConsentState.granted;

  Future<void> setConsent(ConsentState state) async {
    _consent = state;
    await _store.write(_consentKey, state.name);
    if (state == ConsentState.denied) {
      await _queue.clear();
      _pendingRegister = null;
      _pendingIdentify = null;
      await _store.delete(_registerKey);
      await _store.delete(_identifyKey);
    }
  }

  Future<void> identify(
    String userId, {
    String? userHash,
    String? email,
    String? phone,
    Map<String, Object?> traits = const {},
    Map<MarketingChannel, bool> marketingConsent = const {},
  }) async {
    validateIdentity(
      userId: userId,
      userHash: userHash,
      email: email,
      phone: phone,
      traits: traits,
    );
    _userId = userId;
    await _store.write(_userKey, userId);
    if (!canCollect) return;
    _pendingIdentify = buildIdentify(
      installId: _installId,
      userId: userId,
      userHash: userHash,
      email: email,
      phone: phone,
      traits: traits,
      marketingConsent: marketingConsent,
      pending: _pendingIdentify,
    );
    await _store.write(_identifyKey, jsonEncode(_pendingIdentify));
    await flush(force: true);
  }

  Future<void> logout() async {
    _userId = null;
    _pendingIdentify = null;
    await _store.delete(_userKey);
    await _store.delete(_identifyKey);
  }

  Future<void> register(RegisterInfo info) async {
    if (!canCollect) return;
    final granted = info.pushStatus == 'granted';
    _pendingRegister = {
      'installId': _installId,
      'platform': info.platform,
      'sdkVersion': sdkVersion,
      'appVersion': ?(info.appVersion ?? config.appVersion),
      'timezone': ?info.timezone,
      'locale': ?info.locale,
      'pushStatus': info.pushStatus,
      'pushToken': ?(granted ? info.pushToken : null),
    };
    await _store.write(_registerKey, jsonEncode(_pendingRegister));
    await flush(force: true);
  }

  Future<void> track(
    String name, {
    Map<String, Object?> props = const {},
    String? screen,
    DateTime? at,
  }) async {
    validateEventName(name);
    validateProps(props);
    if (!canCollect) return;
    await _queue.add({
      'eventId': _ids.event(),
      'name': name,
      'installId': _installId,
      'userId': ?_userId,
      'screen': ?screen,
      'at': (at ?? _clock.now()).toUtc().toIso8601String(),
      if (props.isNotEmpty) 'props': Map<String, Object?>.from(props),
    });
    if (_queue.length >= config.batchSize) {
      unawaited(flush(fullBatchesOnly: true));
    }
  }

  Future<FlushResult> flush({
    bool force = false,
    bool fullBatchesOnly = false,
  }) {
    final running = _flushing;
    if (running != null) {
      if (fullBatchesOnly || !_flushingFullOnly) return running;
      return running.then((_) => flush(force: force));
    }
    _flushingFullOnly = fullBatchesOnly;
    final next = _flush(
      force,
      fullBatchesOnly,
    ).whenComplete(() => _flushing = null);
    _flushing = next;
    return next;
  }

  Future<ReplayDelivery> postReplay(Map<String, Object?> chunk) async {
    if (!canCollect) return ReplayDelivery.dropped;
    try {
      final response = await _transport.post(
        _url('/v1/replay'),
        _headers,
        jsonEncode(chunk),
      );
      final status = response.status;
      if (status == 200) return ReplayDelivery.sent;
      if (status == 403) return ReplayDelivery.disabled;
      if (status == 400 || status == 409 || status == 413 || status == 422) {
        return ReplayDelivery.dropped;
      }
      return ReplayDelivery.retry;
    } on TransportException {
      return ReplayDelivery.retry;
    }
  }

  Future<void> forget() async {
    _timer?.cancel();
    await _queue.clear();
    for (final key in [
      _installKey,
      _userKey,
      _consentKey,
      _registerKey,
      _identifyKey,
    ]) {
      await _store.delete(key);
    }
    _pendingRegister = null;
    _pendingIdentify = null;
    _userId = null;
    _consent = ConsentState.unknown;
    _installId = _ids.install();
    await _store.write(_installKey, _installId);
  }

  void close() => _timer?.cancel();

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'authorization': 'Bearer ${config.publicKey}',
    'x-engage-app': ?config.appId,
  };

  Uri _url(String path) => config.endpoint.replace(
    path: '${config.endpoint.path.replaceAll(RegExp(r'/+$'), '')}$path',
  );

  FlushResult _result(int sent, int dropped, int? status) => FlushResult(
    sent: sent,
    dropped: dropped,
    pending: _queue.length,
    retryAt: _retryAt,
    lastStatus: status,
  );

  void _fail() {
    _failures += 1;
    final seconds = min(
      _maxBackoff.inSeconds,
      _baseBackoff.inSeconds * pow(2, _failures - 1).toInt(),
    );
    _retryAt = _clock.now().add(Duration(seconds: seconds));
  }

  Future<FlushResult> _flush(bool force, bool fullBatchesOnly) async {
    if (!canCollect) return _result(0, 0, null);
    final retryAt = _retryAt;
    if (!force && retryAt != null && _clock.now().isBefore(retryAt)) {
      return _result(0, 0, null);
    }
    int? status;
    final register = _pendingRegister;
    if (register != null) {
      try {
        final response = await _transport.post(
          _url('/v1/register'),
          _headers,
          jsonEncode(register),
        );
        status = response.status;
        if (status == 200 || status == 400) {
          _pendingRegister = null;
          await _store.delete(_registerKey);
        } else {
          _fail();
          return _result(0, 0, status);
        }
      } on TransportException {
        _fail();
        return _result(0, 0, null);
      }
    }
    final identify = _pendingIdentify;
    if (identify != null) {
      try {
        final response = await _transport.post(
          _url('/v1/identify'),
          _headers,
          jsonEncode(identify),
        );
        status = response.status;
        if (status == 200 || status == 400) {
          _pendingIdentify = null;
          await _store.delete(_identifyKey);
        } else {
          _fail();
          return _result(0, 0, status);
        }
      } on TransportException {
        _fail();
        return _result(0, 0, null);
      }
    }
    var sent = 0;
    var dropped = 0;
    while (true) {
      final taken = await _queue.head(config.batchSize);
      if (taken.rawCount == 0 ||
          (fullBatchesOnly && taken.rawCount < config.batchSize)) {
        break;
      }
      final batch = taken.events;
      if (batch.isEmpty) {
        await _queue.removeFirst(taken.rawCount);
        continue;
      }
      try {
        final response = await _transport.post(
          _url('/v1/events'),
          _headers,
          jsonEncode({
            'sentAt': _clock.now().toUtc().toIso8601String(),
            'events': batch,
          }),
        );
        status = response.status;
        if (status == 200) {
          sent += batch.length;
        } else if (status == 400 || status == 422) {
          dropped += batch.length;
        } else {
          _fail();
          return _result(sent, dropped, status);
        }
        await _queue.removeFirst(taken.rawCount);
        _failures = 0;
        _retryAt = null;
      } on TransportException {
        _fail();
        return _result(sent, dropped, null);
      }
    }
    _failures = 0;
    _retryAt = null;
    return _result(sent, dropped, status);
  }
}
