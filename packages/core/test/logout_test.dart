import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('logout tells the server to unlink this install', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport);
    await client.identify('user_1');
    await client.logout();
    final call = transport.to('/v1/logout').single;
    expect(call.json, {'installId': client.installId});
    expect(call.headers['authorization'], 'Bearer $testKey');
  });

  test('logout without a signed-in person sends nothing', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport);
    await client.logout();
    expect(transport.to('/v1/logout'), isEmpty);
  });

  test('a logout that could not be sent is kept and retried', () async {
    final store = MemoryStore();
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport, store: store);
    await client.identify('user_1');
    transport.script.add(const TransportException('offline'));
    await client.logout();
    expect(await store.read('ft_engage.logout'), isNotNull);
    expect(transport.to('/v1/logout'), hasLength(1));

    final restarted = await makeClient(transport: transport, store: store);
    await restarted.flush(force: true);
    expect(transport.to('/v1/logout'), hasLength(2));
    expect(await store.read('ft_engage.logout'), isNull);
    await restarted.flush(force: true);
    expect(transport.to('/v1/logout'), hasLength(2));
  });

  test('an unlink always goes before the next person is identified', () async {
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport);
    await client.identify('user_1');
    transport.fallbackStatus = 500;
    await client.logout();
    await client.identify('user_2');
    transport.fallbackStatus = 200;
    await client.flush(force: true);
    final paths = transport.calls.map((c) => c.url.path).toList();
    expect(paths.sublist(paths.length - 2), ['/v1/logout', '/v1/identify']);
    expect(transport.to('/v1/identify').last.json['userId'], 'user_2');
  });

  test('an unknown install on the server settles the logout', () async {
    final store = MemoryStore();
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport, store: store);
    await client.identify('user_1');
    transport.script.add(404);
    await client.logout();
    expect(await store.read('ft_engage.logout'), isNull);
  });

  test('denying consent drops a waiting logout, and forget does too', () async {
    final store = MemoryStore();
    final transport = ScriptedTransport();
    final client = await makeClient(transport: transport, store: store);
    await client.identify('user_1');
    transport.script.add(500);
    await client.logout();
    expect(await store.read('ft_engage.logout'), isNotNull);
    await client.setConsent(ConsentState.denied);
    expect(await store.read('ft_engage.logout'), isNull);

    await client.setConsent(ConsentState.granted);
    await client.identify('user_2');
    transport.script.add(500);
    await client.logout();
    await client.forget();
    expect(await store.read('ft_engage.logout'), isNull);
  });
}
