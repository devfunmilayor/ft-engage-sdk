import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test(
    'identify links the install to the person with contact, traits and consent',
    () async {
      final transport = ScriptedTransport();
      final client = await makeClient(transport: transport);
      await client.identify(
        'user_1',
        email: 'ada@example.com',
        phone: '+2348012345678',
        traits: {
          'plan': 'free',
          'age': 31,
          'verified': false,
          'nickname': null,
        },
        marketingConsent: {
          MarketingChannel.email: true,
          MarketingChannel.whatsapp: false,
        },
      );
      final call = transport.to('/v1/identify').single;
      expect(call.headers['authorization'], 'Bearer $testKey');
      expect(call.json, {
        'installId': client.installId,
        'userId': 'user_1',
        'email': 'ada@example.com',
        'phone': '+2348012345678',
        'traits': {
          'plan': 'free',
          'age': 31,
          'verified': false,
          'nickname': null,
        },
        'consent': {'email': 'granted', 'whatsapp': 'denied'},
      });
      expect(client.userId, 'user_1');
      expect(client.pendingCount, 0);
    },
  );

  test(
    'a bare user id still links the install and omits empty fields',
    () async {
      final transport = ScriptedTransport();
      final client = await makeClient(transport: transport);
      await client.identify('user_1');
      expect(transport.to('/v1/identify').single.json, {
        'installId': client.installId,
        'userId': 'user_1',
      });
    },
  );

  test(
    'registration goes first so the server knows the install, then identity, then events',
    () async {
      final transport = ScriptedTransport()..script.add(500);
      final client = await makeClient(transport: transport);
      await client.register(const RegisterInfo(platform: 'android'));
      await client.track('app.opened');
      await client.identify('user_1');
      await client.flush(force: true);
      expect(transport.calls.map((c) => c.url.path).toList(), [
        '/v1/register',
        '/v1/register',
        '/v1/identify',
        '/v1/events',
      ]);
    },
  );

  test('bad identity is rejected before anything is stored or sent', () async {
    final transport = ScriptedTransport();
    final store = MemoryStore();
    final client = await makeClient(transport: transport, store: store);
    final bad = <Future<void> Function()>[
      () => client.identify(''),
      () => client.identify('has space'),
      () => client.identify('x' * 129),
      () => client.identify('u', email: 'nope'),
      () => client.identify('u', phone: '08012345678'),
      () => client.identify('u', traits: {'Plan': 'x'}),
      () => client.identify('u', traits: {'password': 'x'}),
      () => client.identify('u', traits: {'account_balance': 5}),
      () => client.identify(
        'u',
        traits: {
          'plan': {'a': 1},
        },
      ),
      () => client.identify('u', traits: {'plan': 'x' * 201}),
      () => client.identify('u', traits: {'ratio': double.nan}),
      () =>
          client.identify('u', traits: {for (var i = 0; i < 31; i++) 't$i': i}),
    ];
    for (final attempt in bad) {
      await expectLater(attempt(), throwsA(isA<InvalidIdentityException>()));
    }
    expect(transport.calls, isEmpty);
    expect(client.userId, isNull);
    expect(await store.read('ft_engage.identify'), isNull);
  });

  test(
    'identity waits through an outage, survives a restart and is sent once',
    () async {
      final store = MemoryStore();
      final transport = ScriptedTransport()
        ..script.addAll([const TransportException('offline')]);
      final first = await makeClient(transport: transport, store: store);
      await first.identify('user_1', email: 'ada@example.com');
      expect(
        await store.read('ft_engage.identify'),
        contains('ada@example.com'),
      );
      final second = await makeClient(transport: transport, store: store);
      await second.flush(force: true);
      expect(transport.to('/v1/identify'), hasLength(2));
      expect(await store.read('ft_engage.identify'), isNull);
      await second.flush(force: true);
      expect(transport.to('/v1/identify'), hasLength(2));
    },
  );

  test(
    'a rejected payload is dropped but a server error or unknown install is retried later',
    () async {
      final clock = FakeClock(epoch);
      final transport = ScriptedTransport()..script.addAll([400]);
      final client = await makeClient(transport: transport, clock: clock);
      await client.identify('user_1');
      await client.flush(force: true);
      expect(transport.to('/v1/identify'), hasLength(1));

      for (final status in [404, 500, 429]) {
        final t = ScriptedTransport()..script.add(status);
        final c = await makeClient(transport: t, clock: clock);
        await c.identify('user_1');
        expect(t.to('/v1/identify'), hasLength(1));
        clock.advance(const Duration(minutes: 6));
        await c.flush();
        expect(t.to('/v1/identify'), hasLength(2), reason: 'status $status');
      }
    },
  );

  test(
    'calls made while offline merge into one payload for the same person',
    () async {
      final transport = ScriptedTransport()..script.addAll([500, 500]);
      final client = await makeClient(transport: transport);
      await client.identify(
        'user_1',
        email: 'a@example.com',
        traits: {'plan': 'free', 'city': 'Lagos'},
        marketingConsent: {MarketingChannel.email: true},
      );
      await client.identify(
        'user_1',
        traits: {'plan': 'pro', 'city': null},
        marketingConsent: {MarketingChannel.sms: false},
      );
      await client.flush(force: true);
      final last = transport.to('/v1/identify').last.json;
      expect(last['email'], 'a@example.com');
      expect(last['traits'], {'plan': 'pro', 'city': null});
      expect(last['consent'], {'email': 'granted', 'sms': 'denied'});
    },
  );

  test('a different person replaces anything still waiting', () async {
    final transport = ScriptedTransport()..script.add(500);
    final client = await makeClient(transport: transport);
    await client.identify('ada', email: 'ada@example.com');
    await client.identify('bola');
    final last = transport.to('/v1/identify').last.json;
    expect(last['userId'], 'bola');
    expect(last.containsKey('email'), false);
  });

  test(
    'without consent nothing personal is stored or sent, and denying clears what waits',
    () async {
      final transport = ScriptedTransport();
      final store = MemoryStore();
      final client = await makeClient(
        transport: transport,
        store: store,
        requireConsent: true,
      );
      await client.identify('user_1', email: 'ada@example.com');
      expect(transport.calls, isEmpty);
      expect(await store.read('ft_engage.identify'), isNull);

      await client.setConsent(ConsentState.granted);
      transport.script.add(500);
      await client.identify('user_1', email: 'ada@example.com');
      expect(await store.read('ft_engage.identify'), isNotNull);
      await client.setConsent(ConsentState.denied);
      expect(await store.read('ft_engage.identify'), isNull);
    },
  );

  test(
    'logout stops tagging events but keeps the install and consent',
    () async {
      final transport = ScriptedTransport();
      final store = MemoryStore();
      final client = await makeClient(transport: transport, store: store);
      final install = client.installId;
      await client.identify('user_1');
      await client.logout();
      await client.track('app.opened');
      await client.flush(force: true);
      final event =
          (transport.to('/v1/events').single.json['events'] as List).single
              as Map;
      expect(event.containsKey('userId'), false);
      expect(client.userId, isNull);
      expect(client.installId, install);
      expect(await store.read('ft_engage.user_id'), isNull);
    },
  );

  test('forget removes a waiting identity too', () async {
    final store = MemoryStore();
    final transport = ScriptedTransport()..script.add(500);
    final client = await makeClient(transport: transport, store: store);
    await client.identify('user_1', email: 'ada@example.com');
    await client.forget();
    expect(await store.read('ft_engage.identify'), isNull);
  });
}
