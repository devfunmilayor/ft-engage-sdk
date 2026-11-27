import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'clock.dart';
import 'storage.dart';

class InsightsConfig {
  const InsightsConfig({
    this.screens = true,
    this.taps = true,
    this.scroll = true,
    this.maxTapsPerScreen = 300,
    this.sampleRate = 1.0,
    this.rageTaps = 3,
    this.rageWindow = const Duration(seconds: 1),
    this.rageRadius = 48,
    this.sessionGap = const Duration(minutes: 30),
    this.normalizeScreens = true,
    this.screenName,
    this.forms = true,
  }) : assert(sampleRate >= 0 && sampleRate <= 1, 'sampleRate is 0 to 1'),
       assert(rageTaps >= 2, 'a rage burst is at least 2 taps');

  final bool screens;
  final bool taps;
  final bool scroll;
  final int maxTapsPerScreen;
  final double sampleRate;
  final int rageTaps;
  final Duration rageWindow;
  final double rageRadius;
  final Duration sessionGap;
  final bool normalizeScreens;
  final String Function(String)? screenName;
  final bool forms;
}

class TapRecord {
  const TapRecord({
    required this.x,
    required this.y,
    required this.dead,
    required this.rage,
  });

  final double x;
  final double y;
  final bool dead;
  final bool rage;
}

abstract class InsightsListener {
  const InsightsListener();

  void sessionStarted(String sid) {}

  void screenChanged(String name) {}

  void tapped(TapRecord tap) {}

  void scrolled(double offset, double contentHeight) {}
}

class TapSample {
  const TapSample({
    required this.x,
    required this.y,
    required this.viewportWidth,
    required this.viewportHeight,
    this.dead = false,
    this.target,
  });

  final double x;
  final double y;
  final double viewportWidth;
  final double viewportHeight;
  final bool dead;
  final String? target;
}

typedef InsightTrack =
    Future<void> Function(
      String name, {
      Map<String, Object?> props,
      String? screen,
      DateTime? at,
    });

final _digits = RegExp(r'^\d+$');
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
final _hex = RegExp(r'^[0-9a-fA-F]{12,}$');
final _token = RegExp(r'^[A-Za-z0-9_-]{16,}$');

bool looksLikeId(String segment) {
  if (_digits.hasMatch(segment) ||
      _uuid.hasMatch(segment) ||
      _hex.hasMatch(segment)) {
    return true;
  }
  return _token.hasMatch(segment) &&
      segment.contains(RegExp(r'\d')) &&
      segment.contains(RegExp(r'[A-Za-z]'));
}

String normalizeScreenName(String name) {
  var path = name.trim();
  for (final cut in ['?', '#']) {
    final at = path.indexOf(cut);
    if (at >= 0) path = path.substring(0, at);
  }
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  return path
      .split('/')
      .map((s) => s.isNotEmpty && looksLikeId(s) ? ':id' : s)
      .join('/');
}

const _pendingKey = 'ft_engage.insights.pending';

class _Tap {
  const _Tap(this.at, this.x, this.y);

  final DateTime at;
  final double x;
  final double y;
}

class InsightsRecorder {
  InsightsRecorder({
    required this.config,
    required InsightTrack track,
    Clock clock = const SystemClock(),
    Random? random,
    EngageStorage? storage,
    this.listener,
  }) : _track = track,
       _storage = storage,
       _clock = clock,
       _random = random ?? Random.secure();

  final InsightsConfig config;
  final InsightTrack _track;
  final Clock _clock;
  final Random _random;
  final EngageStorage? _storage;
  final InsightsListener? listener;
  String? _sid;
  bool _sampled = true;
  DateTime? _lastActivity;
  String? _screen;
  int _tapsOnScreen = 0;
  double? _maxScroll;
  double? _persistedScroll;
  double? _scrollOffset;
  double? _contentHeight;
  final List<_Tap> _recent = [];
  bool _rageActive = false;

  String? get screen => _screen;
  String? get sessionId => _sid;

  bool _active() {
    final now = _clock.now();
    final last = _lastActivity;
    if (_sid == null ||
        last == null ||
        now.difference(last) > config.sessionGap) {
      _sid =
          's${List.generate(4, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
      _sampled =
          config.sampleRate >= 1 || _random.nextDouble() < config.sampleRate;
      _lastActivity = now;
      listener?.sessionStarted(_sid!);
    }
    _lastActivity = now;
    return _sampled;
  }

  void _emit(
    String name,
    Map<String, Object?> props, {
    String? screen,
    DateTime? at,
  }) {
    unawaited(
      _track(
        name,
        props: props,
        screen: screen ?? _screen,
        at: at,
      ).catchError((Object _) {}),
    );
  }

  void screenViewed(String name) {
    final custom = config.screenName;
    final named = custom != null
        ? custom(name)
        : config.normalizeScreens
        ? normalizeScreenName(name)
        : name;
    final clean = named.trim();
    if (clean.isEmpty || clean.length > 128 || clean == _screen) return;
    leaveScreen();
    final sampled = _active();
    final previous = _screen;
    _screen = clean;
    _tapsOnScreen = 0;
    _scrollOffset = null;
    _contentHeight = null;
    _recent.clear();
    _rageActive = false;
    listener?.screenChanged(clean);
    if (config.screens && sampled) {
      _emit('screen.viewed', {'sid': _sid, 'from': ?previous});
    }
  }

  double _unit(double value) => (value.clamp(0.0, 1.0) * 1000).round() / 1000;

  void tap(TapSample sample) {
    if (!config.taps || _screen == null) return;
    if (sample.viewportWidth <= 0 || sample.viewportHeight <= 0) return;
    final sampled = _active();
    final burst = _detectRage(sample);
    listener?.tapped(
      TapRecord(
        x: sample.x,
        y: sample.y,
        dead: sample.dead,
        rage: burst != null,
      ),
    );
    if (!sampled || _tapsOnScreen >= config.maxTapsPerScreen) return;
    _tapsOnScreen += 1;
    final props = <String, Object?>{
      'x': _unit(sample.x / sample.viewportWidth),
      'y': _unit(sample.y / sample.viewportHeight),
      'vw': sample.viewportWidth.round(),
      'vh': sample.viewportHeight.round(),
      'sid': _sid,
      if (_contentHeight != null) 'so': (_scrollOffset ?? 0).round(),
      if (_contentHeight != null) 'ch': _contentHeight!.round(),
      if (sample.dead) 'dead': true,
      'target': ?sample.target,
    };
    _emit('ui.tap', props);
    if (burst != null) {
      _emit('ui.rage_tap', {
        'x': props['x'],
        'y': props['y'],
        'vw': props['vw'],
        'vh': props['vh'],
        'sid': props['sid'],
        'so': ?props['so'],
        'ch': ?props['ch'],
        'taps': burst,
        'target': ?props['target'],
      });
    }
  }

  int? _detectRage(TapSample sample) {
    final now = _clock.now();
    _recent.removeWhere((t) => now.difference(t.at) > config.rageWindow);
    if (_recent.isEmpty) _rageActive = false;
    _recent.add(_Tap(now, sample.x, sample.y));
    final cluster = _recent
        .where(
          (t) =>
              sqrt(pow(t.x - sample.x, 2) + pow(t.y - sample.y, 2)) <=
              config.rageRadius,
        )
        .length;
    if (cluster >= config.rageTaps && !_rageActive) {
      _rageActive = true;
      return cluster;
    }
    return null;
  }

  void metrics({required double offset, required double contentHeight}) {
    if (_screen == null ||
        !offset.isFinite ||
        !contentHeight.isFinite ||
        contentHeight <= 0) {
      return;
    }
    _scrollOffset = offset < 0 ? 0 : offset;
    _contentHeight = contentHeight;
    listener?.scrolled(_scrollOffset!, contentHeight);
  }

  void scroll(double fraction, {double? offset, double? contentHeight}) {
    if (offset != null && contentHeight != null) {
      metrics(offset: offset, contentHeight: contentHeight);
    }
    if (!config.scroll || _screen == null || !fraction.isFinite) return;
    if (!_active()) return;
    final value = fraction.clamp(0.0, 1.0);
    if (_maxScroll == null || value > _maxScroll!) {
      _maxScroll = value;
      _persist(value);
    }
  }

  void _persist(double value) {
    final store = _storage;
    final last = _persistedScroll;
    if (store == null || (last != null && value - last < 0.1 && value < 1)) {
      return;
    }
    _persistedScroll = value;
    unawaited(
      store
          .write(
            _pendingKey,
            jsonEncode({
              'screen': _screen,
              'sid': _sid,
              'depth': (value * 100).round(),
              'at': _clock.now().toUtc().toIso8601String(),
            }),
          )
          .catchError((Object _) {}),
    );
  }

  Future<void> recover() async {
    final store = _storage;
    if (store == null || !config.scroll) return;
    try {
      final raw = await store.read(_pendingKey);
      if (raw == null) return;
      await store.delete(_pendingKey);
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      final screen = saved['screen'];
      final depth = saved['depth'];
      final at = DateTime.tryParse('${saved['at']}');
      if (screen is! String ||
          depth is! int ||
          depth < 0 ||
          depth > 100 ||
          at == null) {
        return;
      }
      _emit(
        'ui.scroll_depth',
        {'sid': saved['sid'], 'depth': depth, 'recovered': true},
        screen: screen,
        at: at,
      );
    } on Object {
      await store.delete(_pendingKey).catchError((Object _) {});
    }
  }

  void leaveScreen() {
    final depth = _maxScroll;
    _maxScroll = null;
    _persistedScroll = null;
    final store = _storage;
    if (store != null && depth != null) {
      unawaited(store.delete(_pendingKey).catchError((Object _) {}));
    }
    if (depth == null || !config.scroll || !_sampled || _screen == null) return;
    _emit('ui.scroll_depth', {'sid': _sid, 'depth': (depth * 100).round()});
  }
}
