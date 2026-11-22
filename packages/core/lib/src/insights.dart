import 'dart:async';
import 'dart:math';

import 'clock.dart';

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
    });

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
  }) : _track = track,
       _clock = clock,
       _random = random ?? Random.secure();

  final InsightsConfig config;
  final InsightTrack _track;
  final Clock _clock;
  final Random _random;
  String? _sid;
  bool _sampled = true;
  DateTime? _lastActivity;
  String? _screen;
  int _tapsOnScreen = 0;
  double? _maxScroll;
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
    }
    _lastActivity = now;
    return _sampled;
  }

  void _emit(String name, Map<String, Object?> props) {
    unawaited(
      _track(name, props: props, screen: _screen).catchError((Object _) {}),
    );
  }

  void screenViewed(String name) {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 128 || clean == _screen) return;
    leaveScreen();
    final sampled = _active();
    final previous = _screen;
    _screen = clean;
    _tapsOnScreen = 0;
    _recent.clear();
    _rageActive = false;
    if (config.screens && sampled) {
      _emit('screen.viewed', {'sid': _sid, 'from': ?previous});
    }
  }

  double _unit(double value) => (value.clamp(0.0, 1.0) * 1000).round() / 1000;

  void tap(TapSample sample) {
    if (!config.taps || _screen == null) return;
    if (sample.viewportWidth <= 0 || sample.viewportHeight <= 0) return;
    final sampled = _active();
    if (!sampled || _tapsOnScreen >= config.maxTapsPerScreen) return;
    _tapsOnScreen += 1;
    final props = <String, Object?>{
      'x': _unit(sample.x / sample.viewportWidth),
      'y': _unit(sample.y / sample.viewportHeight),
      'vw': sample.viewportWidth.round(),
      'vh': sample.viewportHeight.round(),
      'sid': _sid,
      if (sample.dead) 'dead': true,
      'target': ?sample.target,
    };
    _emit('ui.tap', props);
    _watchRage(sample, props);
  }

  void _watchRage(TapSample sample, Map<String, Object?> props) {
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
      _emit('ui.rage_tap', {
        'x': props['x'],
        'y': props['y'],
        'vw': props['vw'],
        'vh': props['vh'],
        'sid': props['sid'],
        'taps': cluster,
        'target': ?props['target'],
      });
    }
  }

  void scroll(double fraction) {
    if (!config.scroll || _screen == null || !fraction.isFinite) return;
    if (!_active()) return;
    final value = fraction.clamp(0.0, 1.0);
    if (_maxScroll == null || value > _maxScroll!) _maxScroll = value;
  }

  void leaveScreen() {
    final depth = _maxScroll;
    _maxScroll = null;
    if (depth == null || !config.scroll || !_sampled || _screen == null) return;
    _emit('ui.scroll_depth', {'sid': _sid, 'depth': (depth * 100).round()});
  }
}
