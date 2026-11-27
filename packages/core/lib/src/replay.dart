import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'clock.dart';

class ReplayConfig {
  const ReplayConfig({
    this.sampleRate = 1.0,
    this.maxNodes = 250,
    this.snapshotInterval = const Duration(seconds: 1),
    this.maxSnapshotsPerScreen = 40,
    this.chunkEvents = 100,
    this.chunkBytes = 120000,
    this.chunkInterval = const Duration(seconds: 10),
    this.maxBufferedChunks = 20,
    this.maxSessionEvents = 5000,
    this.scrollInterval = const Duration(milliseconds: 200),
    this.captureFieldText = false,
  }) : assert(sampleRate >= 0 && sampleRate <= 1, 'sampleRate is 0 to 1'),
       assert(maxNodes > 0 && maxNodes <= 250, 'maxNodes is 1 to 250'),
       assert(chunkEvents > 0 && chunkEvents <= 500, 'chunkEvents is 1 to 500');

  final bool captureFieldText;
  final double sampleRate;
  final int maxNodes;
  final Duration snapshotInterval;
  final int maxSnapshotsPerScreen;
  final int chunkEvents;
  final int chunkBytes;
  final Duration chunkInterval;
  final int maxBufferedChunks;
  final int maxSessionEvents;
  final Duration scrollInterval;
}

enum ReplayDelivery { sent, dropped, disabled, retry }

typedef ReplaySend =
    Future<ReplayDelivery> Function(Map<String, Object?> chunk);

const _dayMs = 86400000;

class ReplayBuffer {
  ReplayBuffer({
    required this.config,
    required ReplaySend send,
    required String Function() installId,
    String? platform,
    Clock clock = const SystemClock(),
    Random? random,
  }) : _send = send,
       _installId = installId,
       _platform = platform,
       _clock = clock,
       _random = random ?? Random.secure();

  final ReplayConfig config;
  final ReplaySend _send;
  final String Function() _installId;
  final String? _platform;
  final Clock _clock;
  final Random _random;
  String? _sid;
  bool _recording = false;
  bool _disabled = false;
  DateTime? _started;
  int _seq = 0;
  int _total = 0;
  int _bytes = 0;
  int _snapshotsOnScreen = 0;
  DateTime? _lastSnapshot;
  Timer? _timer;
  List<Map<String, Object?>> _events = [];
  final List<Map<String, Object?>> _unsent = [];
  bool _flushing = false;

  bool get recording => _recording && !_disabled;
  String? get sessionId => _sid;
  int get pendingChunks => _unsent.length;

  void session(String sid) {
    if (sid == _sid) return;
    if (_sid != null) unawaited(flush(end: true));
    _sid = sid;
    _started = _clock.now();
    _seq = 0;
    _total = 0;
    _snapshotsOnScreen = 0;
    _lastSnapshot = null;
    _recording =
        config.sampleRate >= 1 || _random.nextDouble() < config.sampleRate;
    _disabled = false;
  }

  bool _add(Map<String, Object?> event) {
    if (!recording || _started == null) return false;
    final t = _clock.now().difference(_started!).inMilliseconds;
    if (t < 0 || t > _dayMs || _total >= config.maxSessionEvents) return false;
    _total += 1;
    final full = {'t': t, ...event};
    _events.add(full);
    _bytes += jsonEncode(full).length;
    if (_events.length >= config.chunkEvents || _bytes >= config.chunkBytes) {
      unawaited(flush());
    } else {
      _timer ??= Timer(config.chunkInterval, () => unawaited(flush()));
    }
    return true;
  }

  void screen(String name) {
    if (_add({'k': 'screen', 'name': name})) {
      _snapshotsOnScreen = 0;
      _lastSnapshot = null;
    }
  }

  void tap(int x, int y, {bool dead = false, bool rage = false}) {
    _add({
      'k': 'tap',
      'x': x,
      'y': y,
      if (dead) 'dead': true,
      if (rage) 'rage': true,
    });
  }

  void scroll(int offset, {int? contentHeight}) {
    _add({'k': 'scroll', 'so': offset < 0 ? 0 : offset, 'ch': ?contentHeight});
  }

  void mark(String kind) {
    if (kind == 'bg' || kind == 'fg' || kind == 'focus') _add({'k': kind});
  }

  bool wantSnapshot() {
    if (!recording) return false;
    if (_snapshotsOnScreen >= config.maxSnapshotsPerScreen) return false;
    final last = _lastSnapshot;
    return last == null ||
        _clock.now().difference(last) >= config.snapshotInterval;
  }

  void snapshot({
    required int width,
    required int height,
    int? scrollOffset,
    required List<List<Object>> nodes,
  }) {
    if (width <= 0 || height <= 0 || !wantSnapshot()) return;
    final trimmed = nodes.length > config.maxNodes
        ? nodes.sublist(0, config.maxNodes)
        : nodes;
    final added = _add({
      'k': 'snap',
      'w': width,
      'h': height,
      'so': ?scrollOffset,
      'n': trimmed,
    });
    if (added) {
      _snapshotsOnScreen += 1;
      _lastSnapshot = _clock.now();
    }
  }

  Future<void> flush({bool end = false}) async {
    _timer?.cancel();
    _timer = null;
    final sid = _sid;
    final started = _started;
    if (sid != null &&
        started != null &&
        (_events.isNotEmpty || end) &&
        _recording) {
      if (_events.isNotEmpty) {
        _unsent.add({
          'installId': _installId(),
          'sid': sid,
          'seq': _seq,
          'startedAt': started.toUtc().toIso8601String(),
          'platform': ?_platform,
          if (end) 'end': true,
          'events': _events,
        });
        _seq += 1;
      }
      _events = [];
      _bytes = 0;
    }
    while (_unsent.length > config.maxBufferedChunks) {
      _unsent.removeAt(0);
    }
    if (_flushing) return;
    _flushing = true;
    try {
      while (_unsent.isNotEmpty) {
        final result = await _send(_unsent.first);
        if (result == ReplayDelivery.retry) break;
        _unsent.removeAt(0);
        if (result == ReplayDelivery.disabled) {
          _disabled = true;
          _unsent.clear();
          _events = [];
          break;
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void clear() {
    _timer?.cancel();
    _timer = null;
    _events = [];
    _bytes = 0;
    _unsent.clear();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
