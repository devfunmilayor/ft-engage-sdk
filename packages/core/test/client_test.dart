import 'dart:convert';

import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test(
    'track queues events and flush sends them with the bearer key',
    () async {
      final transport = ScriptedTransport();
      final client = await makeClient(transport: transport);
      await client.identify('user_1');
      await client.track('app.opened');
      await client.track(
        'signup.started',
        props: {'plan': 'free'},
        screen: 'Signup',
      );
      expect(client.pendingCount, 2);

      final result = await client.flush();
      expect(result.sent, 2);
      expect(client.pendingCount, 0);
      final call = transport.to('/v1/events').single;
      expect(call.headers['authorization'], 'Bearer $testKey');
      final events = call.json['events'] as List<dynamic>;
      expect((events[1] as Map)['props'], {'plan': 'free'});
      expect((events[0] as Map)['userId'], 'user_1');
      expect((events[0] as Map)['installId'], client.installId);
    },
  );

  test('batches never exceed 50 events', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport, batchSize: 500);
    for (var i = 0; i < 120; i++) {
      await client.track('tick');
    }
    await client.flush(force: true);
    final sizes = [
      for (final c in transport.to('/v1/events'))
        (c.json['events'] as List<dynamic>).length,
    ];
    expect(sizes, [50, 50, 20]);
  });

  test('a network failure keeps events and backs off, then recovers', () async {
    final clock = FakeClock(epoch);
    final transport = ScriptedTransport()
      ..script.add(const TransportException('offline'));
    final client = await makeClient(transport: transport, clock: clock);
    await client.track('app.opened');
    final failed = await client.flush();
    expect(failed.sent, 0);
    expect(failed.pending, 1);
    expect(failed.retryAt, epoch.add(const Duration(seconds: 5)));

    final tooSoon = await client.flush();
    expect(tooSoon.pending, 1);
    expect(transport.calls, hasLength(1));

    clock.advance(const Duration(seconds: 6));
    final recovered = await client.flush();
    expect(recovered.sent, 1);
    expect(client.pendingCount, 0);
  });

  test('backoff doubles and is capped at five minutes', () async {
    final clock = FakeClock(epoch);
    final transport = ScriptedTransport()..fallbackStatus = 503;
    final client = await makeClient(transport: transport, clock: clock);
    await client.track('app.opened');
    final delays = <int>[];
    for (var i = 0; i < 8; i++) {
      final result = await client.flush(force: true);
      delays.add(result.retryAt!.difference(clock.now()).inSeconds);
    }
    expect(delays, [5, 10, 20, 40, 80, 160, 300, 300]);
    expect(client.pendingCount, 1);
  });

  test('429 and 5xx are retried, 400 and 422 drop the batch', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport);
    await client.track('a.one');
    transport.script.add(429);
    expect((await client.flush(force: true)).pending, 1);
    transport.script.add(422);
    final dropped = await client.flush(force: true);
    expect([dropped.dropped, dropped.pending], [1, 0]);
  });

  test('events survive a restart through the store', () async {
    final store = MemoryStore();
    final first = await makeClient(store: store);
    await first.track('app.opened');
    final second = await makeClient(store: store);
    expect(second.installId, first.installId);
    expect(second.pendingCount, 1);
  });

  test('the queue drops the oldest events beyond its limit', () async {
    final client = await EngageClient.create(
      config: EngageConfig(
        publicKey: testKey,
        endpoint: Uri.parse('https://a.example'),
        maxQueueSize: 3,
      ),
      transport: ScriptedTransport(),
      clock: FakeClock(epoch),
      ids: CountingIds(),
    );
    for (var i = 0; i < 5; i++) {
      await client.track('tick');
    }
    expect(client.pendingCount, 3);
  });

  test(
    'register is retried until it succeeds and sends the token only when granted',
    () async {
      final transport = ScriptedTransport()
        ..script.add(const TransportException('offline'));
      final store = MemoryStore();
      final client = await makeClient(transport: transport, store: store);
      await client.register(
        const RegisterInfo(
          platform: 'android',
          pushStatus: 'granted',
          pushToken: 'fcm_token_0000000000000000',
        ),
      );
      expect(transport.to('/v1/register'), hasLength(1));
      await client.flush(force: true);
      final sent = transport.to('/v1/register').last.json;
      expect(sent['pushToken'], 'fcm_token_0000000000000000');
      expect(sent['sdkVersion'], sdkVersion);
      expect(await store.read('ft_engage.register'), isNull);

      await client.register(
        const RegisterInfo(
          platform: 'android',
          pushStatus: 'denied',
          pushToken: 'fcm_token_0000000000000000',
        ),
      );
      expect(
        transport.to('/v1/register').last.json.containsKey('pushToken'),
        isFalse,
      );
    },
  );

  test(
    'with consent required nothing is collected or sent until granted',
    () async {
      final transport = ScriptedTransport();
      final client = await makeClient(
        transport: transport,
        requireConsent: true,
      );
      await client.track('app.opened');
      await client.register(const RegisterInfo(platform: 'ios'));
      await client.flush(force: true);
      expect(client.pendingCount, 0);
      expect(transport.calls, isEmpty);

      await client.setConsent(ConsentState.granted);
      await client.track('app.opened');
      expect((await client.flush()).sent, 1);

      await client.track('later');
      await client.setConsent(ConsentState.denied);
      expect(client.pendingCount, 0);
    },
  );

  test('consent choice survives a restart', () async {
    final store = MemoryStore();
    final first = await makeClient(store: store, requireConsent: true);
    await first.setConsent(ConsentState.granted);
    final second = await makeClient(store: store, requireConsent: true);
    expect(second.consent, ConsentState.granted);
  });

  test(
    'forget clears identity, queue and stored state and issues a new install id',
    () async {
      final store = MemoryStore();
      final client = await makeClient(store: store);
      final before = client.installId;
      await client.identify('user_1');
      await client.track('app.opened');
      await client.forget();
      expect(client.pendingCount, 0);
      expect(client.userId, isNull);
      expect(client.installId, isNot(before));
      expect(await store.read('ft_engage.user_id'), isNull);
      expect(await store.read('ft_engage.queue'), isNull);
      expect(await store.read('ft_engage.install_id'), client.installId);
    },
  );

  test('invalid events throw instead of being queued', () async {
    final client = await makeClient();
    await expectLater(
      client.track('Bad Name'),
      throwsA(isA<InvalidEventException>()),
    );
    await expectLater(
      client.track('ok.name', props: {'order_total': 5}),
      throwsA(isA<InvalidEventException>()),
    );
    expect(client.pendingCount, 0);
  });

  test('a flush already running is shared, not duplicated', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport);
    await client.track('app.opened');
    final results = await Future.wait([client.flush(), client.flush()]);
    expect(transport.to('/v1/events'), hasLength(1));
    expect(results.first, same(results.last));
  });

  test('payloads are plain JSON with ISO timestamps', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport);
    await client.track('app.opened');
    await client.flush();
    final event =
        (transport.to('/v1/events').single.json['events'] as List<dynamic>)
                .single
            as Map<String, dynamic>;
    expect(event['at'], '2026-11-22T12:00:00.000Z');
    expect(jsonEncode(event), isNot(contains('null')));
  });
}
