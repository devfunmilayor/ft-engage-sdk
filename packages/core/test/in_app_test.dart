import 'dart:convert';

import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

Map<String, Object?> message(
  String id, {
  String event = 'app.opened',
  String? screen,
  int maxShows = 2,
  int gap = 24,
}) => {
  'id': id,
  'trigger': {'event': event, 'screen': ?screen},
  'layout': 'modal',
  'title': 'Hi',
  'body': 'Welcome back.',
  'buttonLabel': 'Go',
  'actionUrl': 'myapp://home',
  'delaySeconds': 0,
  'maxShows': maxShows,
  'minHoursBetween': gap,
  'updatedAt': '2026-11-27T10:00:00.000Z',
};

class ReadingTransport extends ScriptedTransport implements ReadTransport {
  String feed = '{"messages":[]}';
  int status = 200;
  final List<Uri> reads = [];

  @override
  Future<TransportResponse> get(Uri url, Map<String, String> headers) async {
    reads.add(url);
    return TransportResponse(status, feed);
  }
}

void main() {
  late FakeClock clock;
  late MemoryStore store;
  late List<(String, Object?)> reported;
  late String? body;
  late int fetches;
  late InAppEngine engine;

  InAppEngine make() => InAppEngine(
    store: store,
    clock: clock,
    track: (name, {props = const {}}) async =>
        reported.add((name, props['message'])),
    fetch: () async {
      fetches++;
      return body;
    },
  );

  setUp(() {
    clock = FakeClock(DateTime.utc(2026, 11, 27, 9));
    store = MemoryStore();
    reported = [];
    fetches = 0;
    body = jsonEncode({
      'messages': [
        message('m1'),
        message('m2', event: 'screen.viewed', screen: 'wallet'),
        {'broken': true},
      ],
    });
    engine = make();
  });

  Future<List<InAppMessage>> fire(String name, [String? screen]) async {
    final seen = <InAppMessage>[];
    final sub = engine.due.listen(seen.add);
    engine.onEvent(name, screen);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return seen;
  }

  test(
    'a matching event offers the message, broken entries are skipped',
    () async {
      await engine.refresh();
      expect(engine.messages.map((m) => m.id), ['m1', 'm2']);
      expect((await fire('app.opened')).single.id, 'm1');
    },
  );

  test('a screen narrows the trigger', () async {
    await engine.refresh();
    expect(await fire('screen.viewed', 'home'), isEmpty);
    expect((await fire('screen.viewed', 'wallet')).single.id, 'm2');
  });

  test('only one message is on screen until it is closed', () async {
    await engine.refresh();
    final first = (await fire('app.opened')).single;
    await engine.shown(first);
    expect(await fire('screen.viewed', 'wallet'), isEmpty);
    await engine.dismissed(first);
    expect((await fire('screen.viewed', 'wallet')).single.id, 'm2');
    expect(reported, [('inapp.shown', 'm1'), ('inapp.dismissed', 'm1')]);
  });

  test('the per-person limits hold across restarts', () async {
    await engine.refresh();
    final m = (await fire('app.opened')).single;
    await engine.shown(m);
    await engine.clicked(m);
    expect(await fire('app.opened'), isEmpty);
    clock.advance(const Duration(hours: 25));
    final again = (await fire('app.opened')).single;
    await engine.shown(again);
    await engine.clicked(again);
    clock.advance(const Duration(days: 3));

    final restarted = make();
    await restarted.load();
    engine = restarted;
    expect(engine.messages, hasLength(2));
    expect(await fire('app.opened'), isEmpty);
  });

  test('its own events never trigger a message', () async {
    body = jsonEncode({
      'messages': [message('m3', event: 'inapp.shown')],
    });
    await engine.refresh();
    expect(await fire('inapp.shown'), isEmpty);
  });

  test(
    'fetching is throttled and a failed fetch keeps what is known',
    () async {
      await engine.refresh();
      await engine.refresh();
      expect(fetches, 1);
      body = null;
      clock.advance(const Duration(minutes: 6));
      await engine.refresh();
      expect(fetches, 2);
      expect(engine.messages, hasLength(2));
    },
  );

  test(
    'the client reads the feed only with a transport that can read',
    () async {
      final plain = await makeClient();
      expect(await plain.fetchInApp(), isNull);

      final reading = ReadingTransport()..feed = jsonEncode({'messages': []});
      final client = await EngageClient.create(
        config: EngageConfig(
          publicKey: testKey,
          endpoint: Uri.parse('https://api.example.com'),
          flushInterval: null,
        ),
        transport: reading,
        storage: MemoryStore(),
        ids: CountingIds(),
      );
      expect(await client.fetchInApp(), '{"messages":[]}');
      expect(reading.reads.single.path, '/v1/in-app');
      expect(
        reading.reads.single.queryParameters['installId'],
        client.installId,
      );
      reading.status = 404;
      expect(await client.fetchInApp(), isNull);

      final heard = <String>[];
      client.onTracked = (name, screen) => heard.add(name);
      await client.track('app.opened');
      expect(heard, ['app.opened']);
    },
  );
}
