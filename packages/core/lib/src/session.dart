import 'dart:convert';

import 'clock.dart';
import 'storage.dart';

typedef SessionTrack =
    Future<void> Function(
      String name, {
      Map<String, Object?> props,
      DateTime? at,
    });

/// Splits app use into sessions the way analytics tools do.
///
/// A session starts when the app opens or comes back after more than
/// [timeout] without activity. When the next session starts, the previous
/// one is reported as `session.ended` with how long it lasted, measured from
/// its start to the last time the app was in use. Each session carries a
/// running number for the install, so the server can tell a first visit
/// from a regular.
class SessionTracker {
  SessionTracker({
    required KeyValueStore store,
    required Clock clock,
    required SessionTrack track,
    this.timeout = const Duration(minutes: 30),
  }) : _store = store,
       _clock = clock,
       _track = track;

  static const storageKey = 'ft_engage.session';

  final KeyValueStore _store;
  final Clock _clock;
  final SessionTrack _track;
  final Duration timeout;

  /// Call when the app opens or returns to the foreground.
  Future<void> foreground() async {
    final now = _clock.now();
    final current = await _load();
    if (current != null && now.difference(current.last) <= timeout) {
      await _save(current.touched(now));
      return;
    }
    if (current != null) {
      await _track(
        'session.ended',
        props: {
          'session_number': current.number,
          'duration_seconds': current.last
              .difference(current.start)
              .inSeconds
              .clamp(0, 86400),
        },
        at: current.last,
      );
    }
    final next = _Session(
      start: now,
      last: now,
      number: (current?.number ?? 0) + 1,
    );
    await _save(next);
    await _track(
      'session.started',
      props: {'session_number': next.number, 'first': next.number == 1},
    );
  }

  /// Call when the app goes to the background, so the session's last
  /// activity is known if the person does not come back in time.
  Future<void> background() async {
    final current = await _load();
    if (current != null) await _save(current.touched(_clock.now()));
  }

  /// The running number of the current session, or `null` before the first.
  Future<int?> number() async => (await _load())?.number;

  Future<_Session?> _load() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return _Session(
        start: DateTime.parse(json['start'] as String),
        last: DateTime.parse(json['last'] as String),
        number: json['number'] as int,
      );
    } on Object {
      return null;
    }
  }

  Future<void> _save(_Session s) => _store.write(
    storageKey,
    jsonEncode({
      'start': s.start.toIso8601String(),
      'last': s.last.toIso8601String(),
      'number': s.number,
    }),
  );
}

class _Session {
  const _Session({
    required this.start,
    required this.last,
    required this.number,
  });

  final DateTime start;
  final DateTime last;
  final int number;

  _Session touched(DateTime at) => _Session(
    start: start,
    last: at.isAfter(last) ? at : last,
    number: number,
  );
}
