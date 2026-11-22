import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

EngageConfig build(String key, String endpoint) =>
    EngageConfig(publicKey: key, endpoint: Uri.parse(endpoint));

void main() {
  appIdTests();
  test('a secret key is refused with a clear message', () {
    expect(
      () => build(
        ['sk', 'live', 'abcdefghijklmnopqrstuvwxyz012345'].join('_'),
        'https://api.example.com',
      ),
      throwsA(
        isA<EngageConfigException>().having(
          (e) => e.message,
          'message',
          contains('secret key'),
        ),
      ),
    );
  });

  test('keys that are not public keys are refused', () {
    expect(
      () => build('hello', 'https://api.example.com'),
      throwsA(isA<EngageConfigException>()),
    );
  });

  test('plain http is only allowed for localhost', () {
    expect(
      () => build(testKey, 'http://api.example.com'),
      throwsA(isA<EngageConfigException>()),
    );
    expect(build(testKey, 'http://localhost:8788').endpoint.port, 8788);
    expect(build(testKey, 'https://api.example.com').endpoint.scheme, 'https');
  });

  test('batch size is capped at 50', () {
    final config = EngageConfig(
      publicKey: testKey,
      endpoint: Uri.parse('https://a.example'),
      batchSize: 500,
    );
    expect(config.batchSize, 50);
  });
}

void appIdTests() {
  test('appId is sent as x-engage-app and only when set', () async {
    final withId = ScriptedTransport();
    final a = await EngageClient.create(
      config: EngageConfig(
        publicKey: testKey,
        endpoint: Uri.parse('https://api.example.com'),
        appId: 'com.example.shop',
      ),
      transport: withId,
      storage: MemoryStore(),
      clock: FakeClock(epoch),
      ids: CountingIds(),
    );
    await a.track('app.opened');
    await a.flush();
    expect(
      withId.to('/v1/events').single.headers['x-engage-app'],
      'com.example.shop',
    );

    final without = ScriptedTransport();
    final b = await makeClient(transport: without);
    await b.track('app.opened');
    await b.flush();
    expect(
      without.to('/v1/events').single.headers.containsKey('x-engage-app'),
      false,
    );
  });

  test('an appId with spaces or slashes is refused', () {
    for (final bad in ['has space', 'a/b', '', 'x' * 151]) {
      expect(
        () => EngageConfig(
          publicKey: testKey,
          endpoint: Uri.parse('https://api.example.com'),
          appId: bad,
        ),
        throwsA(isA<EngageConfigException>()),
        reason: bad,
      );
    }
  });
}
