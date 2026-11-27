import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

class RecordingTransport implements Transport {
  final List<(Uri, Map<String, dynamic>)> calls = [];

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    calls.add((url, jsonDecode(body) as Map<String, dynamic>));
    return const TransportResponse(200, '{}');
  }

  List<Map<String, dynamic>> events() => [
    for (final (url, body) in calls)
      if (url.path == '/v1/events')
        ...(body['events'] as List<dynamic>).cast<Map<String, dynamic>>(),
  ];
}

class FixedPush implements PushSource {
  FixedPush(this.state);

  PushState state;

  @override
  Future<PushState> read() async => state;
}

const key = 'pk_test_abcdefghijklmnopqrstuvwxyz012345';

Future<FtEngage> start(
  RecordingTransport transport, {
  PushSource? push,
  bool consent = false,
  bool observe = false,
  String? timezone,
  Duration? sessionTimeout = const Duration(minutes: 30),
}) => FtEngage.init(
  publicKey: key,
  endpoint: Uri.parse('https://api.example.com'),
  transport: transport,
  storage: MemoryStore(),
  pushSource: push,
  requireConsent: consent,
  observeLifecycle: observe,
  flushInterval: null,
  platformOverride: 'android',
  appVersion: '1.2.3',
  timezone: timezone,
  sessionTimeout: sessionTimeout,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sessions can be turned off', () async {
    final transport = RecordingTransport();
    final engage = await start(transport, sessionTimeout: null);
    await engage.flush();
    expect(transport.events().map((e) => e['name']), ['app.opened']);
    expect(engage.sessions, isNull);
  });

  test('registration sends an IANA time zone the server can use', () async {
    final transport = RecordingTransport();
    await start(transport, timezone: 'Africa/Lagos');
    final register = transport.calls
        .firstWhere((c) => c.$1.path == '/v1/register')
        .$2;
    expect(register['timezone'], 'Africa/Lagos');

    final plain = RecordingTransport();
    await start(plain);
    final sent = plain.calls
        .firstWhere((c) => c.$1.path == '/v1/register')
        .$2['timezone'];
    final now = DateTime.now();
    expect(
      sent,
      resolveTimezone(deviceName: now.timeZoneName, offset: now.timeZoneOffset),
    );
    expect(sent == null || sent == 'UTC' || '$sent'.contains('/'), isTrue);
  });

  test(
    'init registers the device with push state and queues app.opened',
    () async {
      final transport = RecordingTransport();
      final engage = await start(
        transport,
        push: FixedPush(
          const PushState(
            status: 'granted',
            token: 'fcm_token_0000000000000000',
          ),
        ),
      );
      final register = transport.calls
          .firstWhere((c) => c.$1.path == '/v1/register')
          .$2;
      expect(register['platform'], 'android');
      expect(register['pushToken'], 'fcm_token_0000000000000000');
      expect(register['appVersion'], '1.2.3');
      expect(engage.client.pendingCount, 2);
      await engage.flush();
      expect(transport.events().map((e) => e['name']), [
        'app.opened',
        'session.started',
      ]);
      expect(transport.events().last['props'], {
        'session_number': 1,
        'first': true,
      });
      engage.dispose();
    },
  );

  test('with consent required nothing is sent until granted', () async {
    final transport = RecordingTransport();
    final engage = await start(transport, consent: true);
    await engage.flush();
    expect(transport.calls, isEmpty);
    await engage.setConsent(ConsentState.granted);
    expect(transport.calls.any((c) => c.$1.path == '/v1/register'), isTrue);
    engage.dispose();
  });

  testWidgets('foreground and background transitions are tracked and flushed', (
    tester,
  ) async {
    final transport = RecordingTransport();
    late FtEngage engage;
    await tester.runAsync(
      () async => engage = await start(transport, observe: true),
    );
    await tester.runAsync(() async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    expect(
      transport.events().map((e) => e['name']),
      containsAll(['app.opened', 'app.backgrounded']),
    );
    await tester.runAsync(() async {
      final binding = tester.binding;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await engage.flush();
    });
    expect(
      transport.events().map((e) => e['name']),
      contains('app.foregrounded'),
    );
    engage.dispose();
  });

  test(
    'identify sends the person after the device is registered and logout stops tagging events',
    () async {
      final transport = RecordingTransport();
      final engage = await start(transport);
      await engage.identify(
        'user_1',
        email: 'ada@example.com',
        traits: {'plan': 'free'},
        marketingConsent: {MarketingChannel.email: true},
      );
      final paths = [for (final (url, _) in transport.calls) url.path];
      expect(
        paths.indexOf('/v1/register'),
        lessThan(paths.indexOf('/v1/identify')),
      );
      final body = transport.calls
          .firstWhere((c) => c.$1.path == '/v1/identify')
          .$2;
      expect(body['userId'], 'user_1');
      expect(body['consent'], {'email': 'granted'});
      await engage.logout();
      await engage.track('after.logout');
      await engage.flush();
      final event = transport.events().firstWhere(
        (e) => e['name'] == 'after.logout',
      );
      expect(event.containsKey('userId'), false);
      engage.dispose();
    },
  );

  test('forget clears the queue and the identity', () async {
    final transport = RecordingTransport();
    final engage = await start(transport);
    await engage.identify('user_1');
    final before = engage.client.installId;
    await engage.forget();
    expect(engage.client.pendingCount, 0);
    expect(engage.client.userId, isNull);
    expect(engage.client.installId, isNot(before));
    engage.dispose();
  });
}
