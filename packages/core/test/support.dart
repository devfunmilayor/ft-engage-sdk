import 'dart:convert';

import 'package:ft_engage_core/ft_engage_core.dart';

const testKey = 'pk_test_abcdefghijklmnopqrstuvwxyz012345';

class FakeClock implements Clock {
  FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration by) => current = current.add(by);
}

class CountingIds implements IdGenerator {
  int _installs = 0;
  int _events = 0;

  @override
  String install() => 'inst_${(++_installs).toString().padLeft(8, '0')}';

  @override
  String event() => 'evt_${(++_events).toString().padLeft(8, '0')}';
}

class Call {
  Call(this.url, this.headers, this.body);

  final Uri url;
  final Map<String, String> headers;
  final String body;

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

class ScriptedTransport implements Transport {
  final List<Call> calls = [];
  final List<Object> script = [];
  int fallbackStatus = 200;

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    calls.add(Call(url, headers, body));
    final next = script.isEmpty ? fallbackStatus : script.removeAt(0);
    if (next is TransportException) throw next;
    return TransportResponse(next as int, '{}');
  }

  List<Call> to(String path) => calls.where((c) => c.url.path == path).toList();
}

final epoch = DateTime.utc(2026, 11, 22, 12);

Future<EngageClient> makeClient({
  ScriptedTransport? transport,
  FakeClock? clock,
  EngageStorage? store,
  bool requireConsent = false,
  int batchSize = 50,
}) => EngageClient.create(
  config: EngageConfig(
    publicKey: testKey,
    endpoint: Uri.parse('https://api.example.com'),
    requireConsent: requireConsent,
    batchSize: batchSize,
  ),
  transport: transport ?? ScriptedTransport(),
  storage: store ?? MemoryStore(),
  clock: clock ?? FakeClock(epoch),
  ids: CountingIds(),
);
