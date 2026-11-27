import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late FakeClock clock;
  late MemoryStore store;
  late List<(String, Map<String, Object?>, DateTime?)> sent;
  late SessionTracker sessions;

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 11, 27, 9));
    store = MemoryStore();
    sent = [];
    sessions = SessionTracker(
      store: store,
      clock: clock,
      track: (name, {props = const {}, at}) async =>
          sent.add((name, props, at)),
    );
  });

  test('the first open starts session one', () async {
    await sessions.foreground();
    expect(sent.single.$1, 'session.started');
    expect(sent.single.$2, {'session_number': 1, 'first': true});
    expect(await sessions.number(), 1);
  });

  test('coming back within 30 minutes keeps the same session', () async {
    await sessions.foreground();
    clock.advance(const Duration(minutes: 5));
    await sessions.background();
    clock.advance(const Duration(minutes: 20));
    await sessions.foreground();
    expect(sent.map((e) => e.$1), ['session.started']);
  });

  test('a long break ends the old session at its last activity', () async {
    await sessions.foreground();
    clock.advance(const Duration(minutes: 12));
    await sessions.background();
    final lastActive = clock.current;
    clock.advance(const Duration(hours: 3));
    await sessions.foreground();
    expect(sent.map((e) => e.$1), [
      'session.started',
      'session.ended',
      'session.started',
    ]);
    expect(sent[1].$2, {'session_number': 1, 'duration_seconds': 720});
    expect(sent[1].$3, lastActive);
    expect(sent[2].$2, {'session_number': 2, 'first': false});
  });

  test('a damaged saved session starts fresh instead of failing', () async {
    await store.write(SessionTracker.storageKey, 'not json');
    await sessions.foreground();
    expect(sent.single.$2['session_number'], 1);
  });

  test('session events pass the property rules', () {
    for (final name in ['session_number', 'duration_seconds', 'first']) {
      expect(() => validateProps({name: 1}), returnsNormally);
    }
  });
}
