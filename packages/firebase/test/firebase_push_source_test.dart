import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_firebase/ft_engage_firebase.dart';
import 'package:ft_engage_firebase/src/messaging_gateway.dart'
    show mapAuthorization;
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

const firstToken = 'fcm_token_00000000000000000001';
const secondToken = 'fcm_token_00000000000000000002';

class FakeGateway implements MessagingGateway {
  FakeGateway({
    this.current = GatewayPermission.notDetermined,
    this.afterRequest = GatewayPermission.granted,
    this.fcmToken = firstToken,
  });

  GatewayPermission current;
  GatewayPermission afterRequest;
  String? fcmToken;
  Object? permissionError;
  Object? tokenError;
  int asked = 0;
  final StreamController<String> refreshes =
      StreamController<String>.broadcast();

  @override
  Future<GatewayPermission> permission() async {
    if (permissionError != null) throw permissionError!;
    return current;
  }

  @override
  Future<GatewayPermission> requestPermission() async {
    asked += 1;
    current = afterRequest;
    return current;
  }

  @override
  Future<String?> token() async {
    if (tokenError != null) throw tokenError!;
    return fcmToken;
  }

  @override
  Stream<String> get tokenRefreshes => refreshes.stream;
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Firebase authorisation maps to the three states the server understands',
    () {
      expect(
        mapAuthorization(AuthorizationStatus.authorized),
        GatewayPermission.granted,
      );
      expect(
        mapAuthorization(AuthorizationStatus.provisional),
        GatewayPermission.granted,
      );
      expect(
        mapAuthorization(AuthorizationStatus.denied),
        GatewayPermission.denied,
      );
      expect(
        mapAuthorization(AuthorizationStatus.deniedPermanently),
        GatewayPermission.denied,
      );
      expect(
        mapAuthorization(AuthorizationStatus.notDetermined),
        GatewayPermission.notDetermined,
      );
    },
  );

  test(
    'the token is read only when the person allowed notifications',
    () async {
      final gateway = FakeGateway(current: GatewayPermission.granted);
      final source = FirebasePushSource(gateway: gateway);
      expect(
        await source.read(),
        const PushState(status: 'granted', token: firstToken),
      );
      gateway.current = GatewayPermission.denied;
      expect(await source.read(), const PushState(status: 'denied'));
      gateway.current = GatewayPermission.notDetermined;
      expect(await source.read(), PushState.unknown);
    },
  );

  test(
    'a missing, short or failing firstToken still reports permission, and a failing permission reports unknown',
    () async {
      final gateway = FakeGateway(current: GatewayPermission.granted);
      final source = FirebasePushSource(gateway: gateway);
      gateway.fcmToken = null;
      expect(await source.read(), const PushState(status: 'granted'));
      gateway.fcmToken = 'short';
      expect(await source.read(), const PushState(status: 'granted'));
      gateway.fcmToken = firstToken;
      gateway.tokenError = StateError('apns-firstToken-not-set');
      expect(await source.read(), const PushState(status: 'granted'));
      gateway.permissionError = StateError('no firebase');
      expect(await source.read(), PushState.unknown);
      expect(await source.request(), const PushState(status: 'granted'));
    },
  );

  test('asking prompts once per call and returns the new state', () async {
    final gateway = FakeGateway();
    final source = FirebasePushSource(gateway: gateway);
    expect(await source.read(), PushState.unknown);
    expect(gateway.asked, 0);
    expect(
      await source.request(),
      const PushState(status: 'granted', token: firstToken),
    );
    expect(gateway.asked, 1);
    final refused = FakeGateway(afterRequest: GatewayPermission.denied);
    expect(
      await FirebasePushSource(gateway: refused).request(),
      const PushState(status: 'denied'),
    );
  });

  test(
    'every refreshed firstToken is a change, whatever the firstToken is',
    () async {
      final gateway = FakeGateway();
      final source = FirebasePushSource(gateway: gateway);
      var changes = 0;
      final sub = source.changes.listen((_) => changes += 1);
      gateway.refreshes.add(secondToken);
      gateway.refreshes.add('x');
      await Future<void>.delayed(Duration.zero);
      expect(changes, 2);
      await sub.cancel();
    },
  );

  test(
    'with the plugin: registers at start, again when the firstToken rotates, and after the person agrees',
    () async {
      final gateway = FakeGateway();
      final transport = Recording();
      final engage = await FtEngage.init(
        publicKey: 'pk_test_abcdefghijklmnopqrstuvwxyz012345',
        endpoint: Uri.parse('https://api.example.com'),
        transport: transport,
        storage: MemoryStore(),
        pushSource: FirebasePushSource(gateway: gateway),
        observeLifecycle: false,
        flushInterval: null,
        platformOverride: 'android',
      );
      expect(transport.registers.single['pushStatus'], 'unknown');
      final answer = await engage.requestPushPermission();
      expect(answer.status, 'granted');
      expect(transport.registers.last['pushToken'], firstToken);
      gateway.fcmToken = secondToken;
      gateway.refreshes.add(secondToken);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(transport.registers.last['pushToken'], secondToken);
      expect(transport.registers.map((r) => r['pushStatus']).toList(), [
        'unknown',
        'granted',
        'granted',
      ]);
      engage.dispose();
    },
  );
}
