import 'dart:convert';
import 'dart:math';

import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

class Rig {
  Rig({ReplayConfig config = const ReplayConfig(), int seed = 1})
    : clock = FakeClock(epoch) {
    buffer = ReplayBuffer(
      config: config,
      clock: clock,
      random: Random(seed),
      installId: () => 'inst_00000001',
      platform: 'android',
      send: (chunk) async {
        sent.add(chunk);
        return results.isEmpty ? ReplayDelivery.sent : results.removeAt(0);
      },
    );
  }

  final FakeClock clock;
  final List<Map<String, Object?>> sent = [];
  final List<ReplayDelivery> results = [];
  late final ReplayBuffer buffer;

  List<Map<String, Object?>> events(int chunk) =>
      (sent[chunk]['events'] as List).cast<Map<String, Object?>>();
}

const nodes = <List<Object>>[
  ['t', 10, 10, 100, 20],
  ['b', 10, 50, 100, 40, 4278190335],
];

void main() {
  test(
    'events are timed from the start of the session and leave in a chunk with who, when and where',
    () async {
      final rig = Rig();
      rig.buffer.session('s0a1b2c3d');
      rig.buffer.screen('/home');
      rig.clock.advance(const Duration(milliseconds: 250));
      rig.buffer.snapshot(width: 390, height: 844, nodes: nodes);
      rig.clock.advance(const Duration(milliseconds: 650));
      rig.buffer.tap(195, 320);
      rig.clock.advance(const Duration(milliseconds: 600));
      rig.buffer.tap(195, 320, dead: true, rage: true);
      rig.buffer.scroll(640, contentHeight: 3200);
      rig.buffer.scroll(-5);
      rig.buffer.mark('bg');
      rig.buffer.mark('keypress');
      await rig.buffer.flush();
      expect(rig.sent, hasLength(1));
      final chunk = rig.sent.single;
      expect(chunk['installId'], 'inst_00000001');
      expect(chunk['sid'], 's0a1b2c3d');
      expect(chunk['seq'], 0);
      expect(chunk['platform'], 'android');
      expect(chunk['startedAt'], '2026-11-22T12:00:00.000Z');
      expect(chunk.containsKey('end'), false);
      expect(rig.events(0), [
        {'t': 0, 'k': 'screen', 'name': '/home'},
        {'t': 250, 'k': 'snap', 'w': 390, 'h': 844, 'n': nodes},
        {'t': 900, 'k': 'tap', 'x': 195, 'y': 320},
        {'t': 1500, 'k': 'tap', 'x': 195, 'y': 320, 'dead': true, 'rage': true},
        {'t': 1500, 'k': 'scroll', 'so': 640, 'ch': 3200},
        {'t': 1500, 'k': 'scroll', 'so': 0},
        {'t': 1500, 'k': 'bg'},
      ]);
      await rig.buffer.flush();
      expect(rig.sent, hasLength(1));
    },
  );

  test(
    'a chunk goes out by itself when it has enough events, and sequence numbers count up',
    () async {
      final rig = Rig(config: const ReplayConfig(chunkEvents: 3));
      rig.buffer.session('s0a1b2c3d');
      for (var i = 0; i < 7; i++) {
        rig.buffer.tap(i, i);
      }
      await Future<void>.delayed(Duration.zero);
      expect(rig.sent.map((c) => c['seq']).toList(), [0, 1]);
      expect(rig.events(0), hasLength(3));
      await rig.buffer.flush(end: true);
      expect(rig.sent.map((c) => c['seq']).toList(), [0, 1, 2]);
      expect(rig.sent.last['end'], true);
      expect(rig.events(2), hasLength(1));
    },
  );

  test(
    'a chunk also goes out when it is getting large or has waited long enough',
    () async {
      final big = Rig(config: const ReplayConfig(chunkBytes: 400));
      big.buffer.session('s0a1b2c3d');
      big.buffer.snapshot(
        width: 390,
        height: 844,
        nodes: [
          for (var i = 0; i < 30; i++) ['t', i, i, 10, 10],
        ],
      );
      await Future<void>.delayed(Duration.zero);
      expect(big.sent, hasLength(1));

      final slow = Rig(
        config: const ReplayConfig(chunkInterval: Duration(milliseconds: 20)),
      );
      slow.buffer.session('s0a1b2c3d');
      slow.buffer.tap(1, 1);
      expect(slow.sent, isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(slow.sent, hasLength(1));
      slow.buffer.dispose();
    },
  );

  test(
    'a delivery that fails is kept and sent first next time, in order',
    () async {
      final rig = Rig(config: const ReplayConfig(chunkEvents: 1));
      rig.results.addAll([ReplayDelivery.retry, ReplayDelivery.retry]);
      rig.buffer.session('s0a1b2c3d');
      rig.buffer.tap(1, 1);
      await Future<void>.delayed(Duration.zero);
      rig.buffer.tap(2, 2);
      await Future<void>.delayed(Duration.zero);
      expect(rig.buffer.pendingChunks, 2);
      await rig.buffer.flush();
      expect(rig.buffer.pendingChunks, 0);
      expect(
        rig.sent.map((c) => c['seq']).toList().sublist(rig.sent.length - 2),
        [0, 1],
      );
    },
  );

  test(
    'the buffer keeps only the newest chunks when the network stays down',
    () async {
      final rig = Rig(
        config: const ReplayConfig(chunkEvents: 1, maxBufferedChunks: 3),
      );
      rig.results.addAll(List.filled(50, ReplayDelivery.retry));
      rig.buffer.session('s0a1b2c3d');
      for (var i = 0; i < 8; i++) {
        rig.buffer.tap(i, i);
        await Future<void>.delayed(Duration.zero);
      }
      await rig.buffer.flush();
      expect(rig.buffer.pendingChunks, 3);
    },
  );

  test(
    'a rejected chunk is dropped and a server that has replay turned off stops the recording',
    () async {
      final rig = Rig(config: const ReplayConfig(chunkEvents: 1));
      rig.results.add(ReplayDelivery.dropped);
      rig.buffer.session('s0a1b2c3d');
      rig.buffer.tap(1, 1);
      await Future<void>.delayed(Duration.zero);
      expect(rig.buffer.pendingChunks, 0);
      expect(rig.buffer.recording, true);
      rig.results.add(ReplayDelivery.disabled);
      rig.buffer.tap(2, 2);
      await Future<void>.delayed(Duration.zero);
      expect(rig.buffer.recording, false);
      rig.buffer.tap(3, 3);
      await rig.buffer.flush();
      expect(rig.sent, hasLength(2));
      rig.buffer.session('s1111aaaa');
      expect(rig.buffer.recording, true);
    },
  );

  test('a new session closes the old one and starts counting again', () async {
    final rig = Rig();
    rig.buffer.session('s0a1b2c3d');
    rig.buffer.tap(1, 1);
    rig.buffer.session('s0a1b2c3d');
    rig.clock.advance(const Duration(minutes: 40));
    rig.buffer.session('sffff0000');
    await Future<void>.delayed(Duration.zero);
    expect(rig.sent.single['sid'], 's0a1b2c3d');
    expect(rig.sent.single['end'], true);
    rig.clock.advance(const Duration(seconds: 3));
    rig.buffer.tap(2, 2);
    await rig.buffer.flush();
    expect(rig.sent.last['sid'], 'sffff0000');
    expect(rig.sent.last['seq'], 0);
    expect(rig.events(1).single['t'], 3000);
    expect(rig.sent.last['startedAt'], '2026-11-22T12:40:00.000Z');
  });

  test(
    'sampling decides per session and records nothing for sessions left out',
    () async {
      final none = Rig(config: const ReplayConfig(sampleRate: 0));
      none.buffer.session('s0a1b2c3d');
      none.buffer.screen('/home');
      none.buffer.tap(1, 1);
      none.buffer.snapshot(width: 100, height: 100, nodes: nodes);
      await none.buffer.flush(end: true);
      expect(none.sent, isEmpty);
      expect(none.buffer.recording, false);
      var kept = 0;
      for (var seed = 0; seed < 200; seed++) {
        final rig = Rig(
          config: const ReplayConfig(sampleRate: 0.25),
          seed: seed,
        );
        rig.buffer.session('s0a1b2c3d');
        if (rig.buffer.recording) kept += 1;
      }
      expect(kept, inInclusiveRange(25, 75));
    },
  );

  test(
    'snapshots are paced, capped per screen, trimmed and need a real size',
    () async {
      final rig = Rig(
        config: const ReplayConfig(maxSnapshotsPerScreen: 2, maxNodes: 3),
      );
      rig.buffer.session('s0a1b2c3d');
      rig.buffer.screen('/home');
      expect(rig.buffer.wantSnapshot(), true);
      rig.buffer.snapshot(width: 0, height: 100, nodes: nodes);
      rig.buffer.snapshot(width: 100, height: -1, nodes: nodes);
      rig.buffer.snapshot(
        width: 100,
        height: 100,
        nodes: [
          for (var i = 0; i < 9; i++) ['t', i, 0, 5, 5],
        ],
      );
      expect(rig.buffer.wantSnapshot(), false);
      rig.buffer.snapshot(width: 100, height: 100, nodes: nodes);
      rig.clock.advance(const Duration(seconds: 2));
      rig.buffer.snapshot(
        width: 100,
        height: 100,
        scrollOffset: 300,
        nodes: nodes,
      );
      rig.clock.advance(const Duration(seconds: 2));
      expect(rig.buffer.wantSnapshot(), false);
      rig.buffer.snapshot(width: 100, height: 100, nodes: nodes);
      rig.buffer.screen('/next');
      expect(rig.buffer.wantSnapshot(), true);
      await rig.buffer.flush();
      final snaps = rig.events(0).where((e) => e['k'] == 'snap').toList();
      expect(snaps, hasLength(2));
      expect((snaps[0]['n'] as List), hasLength(3));
      expect(snaps[1]['so'], 300);
    },
  );

  test(
    'a runaway session stops at its event limit and nothing past a day is kept',
    () async {
      final rig = Rig(
        config: const ReplayConfig(maxSessionEvents: 5, chunkEvents: 500),
      );
      rig.buffer.session('s0a1b2c3d');
      for (var i = 0; i < 20; i++) {
        rig.buffer.tap(i, i);
      }
      await rig.buffer.flush();
      expect(rig.events(0), hasLength(5));
      final day = Rig();
      day.buffer.session('s0a1b2c3d');
      day.clock.advance(const Duration(hours: 25));
      day.buffer.tap(1, 1);
      await day.buffer.flush();
      expect(day.sent, isEmpty);
    },
  );

  test('a chunk is plain JSON with no text in it', () async {
    final rig = Rig();
    rig.buffer.session('s0a1b2c3d');
    rig.buffer.screen('/home');
    rig.buffer.snapshot(width: 390, height: 844, nodes: nodes);
    rig.buffer.tap(10, 10);
    await rig.buffer.flush();
    final text = jsonEncode(rig.sent.single);
    expect(jsonDecode(text), isA<Map<String, dynamic>>());
    expect(text.contains('Hello'), false);
  });

  test(
    'the client sends a chunk with the public key and reports what the server said',
    () async {
      final transport = ScriptedTransport();
      final client = await makeClient(transport: transport);
      final chunk = {
        'installId': client.installId,
        'sid': 's0a1b2c3d',
        'seq': 0,
        'startedAt': '2026-11-22T12:00:00.000Z',
        'events': [],
      };
      expect(await client.postReplay(chunk), ReplayDelivery.sent);
      final call = transport.to('/v1/replay').single;
      expect(call.headers['authorization'], 'Bearer $testKey');
      expect(call.json['sid'], 's0a1b2c3d');
      final cases = {
        403: ReplayDelivery.disabled,
        400: ReplayDelivery.dropped,
        409: ReplayDelivery.dropped,
        413: ReplayDelivery.dropped,
        422: ReplayDelivery.dropped,
        429: ReplayDelivery.retry,
        500: ReplayDelivery.retry,
        401: ReplayDelivery.retry,
      };
      for (final entry in cases.entries) {
        transport.script.add(entry.key);
        expect(
          await client.postReplay(chunk),
          entry.value,
          reason: '${entry.key}',
        );
      }
      transport.script.add(const TransportException('offline'));
      expect(await client.postReplay(chunk), ReplayDelivery.retry);
    },
  );

  test('without consent nothing is sent', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport, requireConsent: true);
    expect(await client.postReplay({'a': 1}), ReplayDelivery.dropped);
    expect(transport.calls, isEmpty);
  });
}
