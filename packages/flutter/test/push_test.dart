import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

class Recording implements Transport {
  final List<Map<String, dynamic>> registers = [];

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    if (url.path == '/v1/register') {
      registers.add(jsonDecode(body) as Map<String, dynamic>);
    }
    return const TransportResponse(200, '{}');
  }
}

class PlainSource implements PushSource {
  PlainSource(this.state);

  PushState state;

  @override
  Future<PushState> read() async => state;
}

class FullSource extends PlainSource implements PushChanges, PushPermission {
  FullSource(super.state, {this.afterRequest});

  final PushState? afterRequest;
  final StreamController<void> controller = StreamController<void>.broadcast();
  int requests = 0;

  @override
  Stream<void> get changes => controller.stream;

  @override
  Future<PushState> request() async {
    requests += 1;
    state = afterRequest ?? state;
    return state;
  }
}

const key = 'pk_test_abcdefghijklmnopqrstuvwxyz012345';
const token = 'fcm_token_0000000000000001';
const rotated = 'fcm_token_0000000000000002';

Future<(FtEngage, Recording)> start(
  PushSource? source, {
  bool consent = false,
}) async {
  final transport = Recording();
  final engage = await FtEngage.init(
    publicKey: key,
    endpoint: Uri.parse('https://api.example.com'),
    transport: transport,
    storage: MemoryStore(),
    pushSource: source,
    requireConsent: consent,
    observeLifecycle: false,
    flushInterval: null,
    platformOverride: 'android',
  );
  return (engage, transport);
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the device registers with its push state and token at start', () async {
    final (engage, transport) = await start(
      FullSource(const PushState(status: 'granted', token: token)),
    );
    expect(transport.registers.single['pushStatus'], 'granted');
    expect(transport.registers.single['pushToken'], token);
    engage.dispose();
  });

  test(
    'a new token or a changed permission is registered again, and a repeat is not',
    () async {
      final source = FullSource(
        const PushState(status: 'granted', token: token),
      );
      final (engage, transport) = await start(source);
      source.state = const PushState(status: 'granted', token: rotated);
      source.controller.add(null);
      await settle();
      expect(transport.registers.map((r) => r['pushToken']), [token, rotated]);
      source.controller.add(null);
      await settle();
      expect(transport.registers, hasLength(2));
      source.state = const PushState(status: 'denied');
      source.controller.add(null);
      await settle();
      expect(transport.registers.last['pushStatus'], 'denied');
      expect(transport.registers.last.containsKey('pushToken'), false);
      engage.dispose();
    },
  );

  test(
    'asking for permission registers the new state, and the answer is returned',
    () async {
      final source = FullSource(
        const PushState(status: 'unknown'),
        afterRequest: const PushState(status: 'granted', token: token),
      );
      final (engage, transport) = await start(source);
      expect(transport.registers.single['pushStatus'], 'unknown');
      final answer = await engage.requestPushPermission();
      expect(
        [answer.status, answer.token, source.requests],
        ['granted', token, 1],
      );
      expect(transport.registers.last['pushStatus'], 'granted');
      expect(transport.registers.last['pushToken'], token);
      engage.dispose();
    },
  );

  test(
    'a source that cannot ask or notify still works, and asking is harmless',
    () async {
      final source = PlainSource(
        const PushState(status: 'granted', token: token),
      );
      final (engage, transport) = await start(source);
      final answer = await engage.requestPushPermission();
      expect(answer.status, 'granted');
      expect(transport.registers, hasLength(1));
      final (bare, bareTransport) = await start(null);
      expect((await bare.requestPushPermission()).status, 'unknown');
      expect(bareTransport.registers.single['pushStatus'], 'unknown');
      engage.dispose();
      bare.dispose();
    },
  );

  test(
    'after dispose nothing more is registered, and a failing stream does not break the app',
    () async {
      final source = FullSource(
        const PushState(status: 'granted', token: token),
      );
      final (engage, transport) = await start(source);
      source.controller.addError(StateError('boom'));
      await settle();
      source.state = const PushState(status: 'granted', token: rotated);
      engage.dispose();
      source.controller.add(null);
      await settle();
      expect(transport.registers, hasLength(1));
    },
  );

  test(
    'without consent a change is not sent, and it is sent once consent is given',
    () async {
      final source = FullSource(
        const PushState(status: 'granted', token: token),
      );
      final (engage, transport) = await start(source, consent: true);
      source.state = const PushState(status: 'granted', token: rotated);
      source.controller.add(null);
      await settle();
      expect(transport.registers, isEmpty);
      await engage.setConsent(ConsentState.granted);
      expect(transport.registers.last['pushToken'], rotated);
      engage.dispose();
    },
  );
}
