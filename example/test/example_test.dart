import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_example/example_app.dart';
import 'package:ft_engage_example/switchable_transport.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

class MockServer implements Transport {
  final List<Map<String, dynamic>> events = [];
  final Set<String> seen = {};

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    if (url.path == '/v1/events') {
      for (final e
          in ((jsonDecode(body) as Map)['events'] as List<dynamic>)
              .cast<Map<String, dynamic>>()) {
        if (seen.add(e['eventId'] as String)) events.add(e);
      }
    }
    return const TransportResponse(200, '{}');
  }
}

void main() {
  testWidgets(
    'identify, track, go offline, come back and deliver exactly once',
    (tester) async {
      final server = MockServer();
      final transport = SwitchableTransport(server);
      late FtEngage engage;
      await tester.runAsync(() async {
        engage = await FtEngage.init(
          publicKey: 'pk_test_abcdefghijklmnopqrstuvwxyz012345',
          endpoint: Uri.parse('http://localhost:8788'),
          transport: transport,
          storage: MemoryStore(),
          observeLifecycle: false,
          flushInterval: null,
          platformOverride: 'android',
        );
      });
      await tester.pumpWidget(ExampleApp(engage: engage, transport: transport));

      await tester.runAsync(() async {
        transport.offline = true;
        await engage.identify('user_1001');
        await engage.track('button.pressed', props: {'button': 'demo'});
        final offline = await engage.flush();
        expect(offline.sent, 0);
        expect(offline.pending, 2);
        transport.offline = false;
        final online = await engage.flush();
        expect(online.sent, 2);
        await engage.flush();
      });

      expect(server.events.map((e) => e['name']), [
        'app.opened',
        'button.pressed',
      ]);
      expect(server.events.last['userId'], 'user_1001');
      expect(find.text('Install ${engage.client.installId}'), findsOneWidget);
      engage.dispose();
    },
  );
}
