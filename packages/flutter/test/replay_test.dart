import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

class Recording implements Transport {
  final List<Map<String, dynamic>> chunks = [];
  int replayStatus = 200;

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    if (url.path == '/v1/replay') {
      chunks.add(jsonDecode(body) as Map<String, dynamic>);
      return TransportResponse(replayStatus, '{}');
    }
    return const TransportResponse(200, '{}');
  }

  List<Map<String, dynamic>> events() => [
    for (final chunk in chunks)
      ...(chunk['events'] as List).cast<Map<String, dynamic>>(),
  ];
}

const key = 'pk_test_abcdefghijklmnopqrstuvwxyz012345';

Future<(FtEngage, Recording)> start({
  ReplayConfig? replay = const ReplayConfig(),
  InsightsConfig? insights,
}) async {
  final transport = Recording();
  final engage = await FtEngage.init(
    publicKey: key,
    endpoint: Uri.parse('https://api.example.com'),
    transport: transport,
    storage: MemoryStore(),
    insights: insights,
    replay: replay,
    observeLifecycle: false,
    flushInterval: null,
    platformOverride: 'android',
  );
  return (engage, transport);
}

Widget app(FtEngage engage, Map<String, WidgetBuilder> routes) => MaterialApp(
  navigatorObservers: [engage.navigatorObserver],
  initialRoute: '/',
  routes: routes,
  builder: (context, child) => EngageInsights(engage: engage, child: child!),
);

List<Map<String, dynamic>> named(
  List<Map<String, dynamic>> events,
  String kind,
) => events.where((e) => e['k'] == kind).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a layout capture sees boxes, buttons, inputs and masks, and never any text',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Ada Lovelace account 12345678'),
                Container(
                  width: 200,
                  height: 40,
                  color: const Color(0xFFFF0000),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Send money'),
                ),
                const TextField(),
                const EngageSensitive(
                  child: SizedBox(
                    width: 200,
                    height: 50,
                    child: Text('4111 1111 1111 1111'),
                  ),
                ),
                Opacity(
                  opacity: 0,
                  child: Container(
                    width: 50,
                    height: 50,
                    color: Colors.blue,
                    child: const Text('hidden'),
                  ),
                ),
                Offstage(child: const Text('offstage')),
              ],
            ),
          ),
        ),
      );
      final snapshot = captureLayout()!;
      expect([snapshot.width, snapshot.height], [800, 600]);
      final kinds = snapshot.nodes.map((n) => n[0]).toList();
      expect(kinds, containsAll(['t', 'b', 'f', 'x', 'm']));
      expect(kinds.where((k) => k == 'm'), hasLength(1));
      final red = snapshot.nodes.firstWhere(
        (n) => n[0] == 'x' && n.length == 6 && n[5] == 0xFFFF0000,
      );
      expect([red[3], red[4]], [200, 40]);
      final text = jsonEncode(snapshot.nodes);
      for (final secret in [
        'Ada',
        'Lovelace',
        '12345678',
        'Send money',
        '4111',
        'hidden',
        'offstage',
      ]) {
        expect(text.contains(secret), false, reason: secret);
      }
      final masked = snapshot.nodes.firstWhere((n) => n[0] == 'm');
      expect([masked[3], masked[4]], [200, 50]);
      expect(
        snapshot.nodes.where((n) => n[0] == 't'),
        hasLength(greaterThanOrEqualTo(2)),
      );
      for (final node in snapshot.nodes) {
        expect(node, anyOf(hasLength(5), hasLength(6)));
        expect(node.skip(1).every((v) => v is int), true);
      }
    },
  );

  testWidgets(
    'a capture keeps to the node limit and only sees what is on the screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < 200; i++)
                  SizedBox(height: 60, child: Text('row $i')),
              ],
            ),
          ),
        ),
      );
      final snapshot = captureLayout(maxNodes: 12)!;
      expect(snapshot.nodes.length, lessThanOrEqualTo(12));
      final full = captureLayout()!;
      expect(full.nodes.length, lessThan(100));
      for (final node in full.nodes) {
        expect(node[2] as int, lessThan(600));
      }
    },
  );

  testWidgets(
    'screens, taps, scrolling and snapshots become a timeline in the order they happened',
    (tester) async {
      final (engage, transport) = await start(
        replay: const ReplayConfig(scrollInterval: Duration.zero),
      );
      await tester.pumpWidget(
        app(engage, {
          '/': (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/next'),
                  child: const Text('Go'),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < 60; i++)
                        SizedBox(height: 80, child: Text('row $i')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          '/next': (_) => const Scaffold(body: Text('next')),
        }),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.fling(find.byType(ListView), const Offset(0, -600), 3000);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await engage.flush();
      await engage.replay!.buffer.flush();
      final events = transport.events();
      expect(events.first['k'], 'screen');
      expect(events.first['name'], '/');
      expect(named(events, 'screen').map((e) => e['name']).toList(), [
        '/',
        '/next',
      ]);
      expect(named(events, 'snap'), isNotEmpty);
      expect(named(events, 'tap'), hasLength(1));
      expect(named(events, 'scroll'), isNotEmpty);
      expect((named(events, 'scroll').last['so'] as int), greaterThan(100));
      final times = events.map((e) => e['t'] as int).toList();
      expect(times, orderedEquals([...times]..sort()));
      expect(transport.chunks.first['seq'], 0);
      expect(transport.chunks.first['sid'], matches(RegExp(r'^s[0-9a-f]{8}$')));
      expect(transport.chunks.first['platform'], 'android');
      engage.dispose();
    },
  );

  testWidgets(
    'taps inside a sensitive area are not in the replay and a text field tap is marked as focus',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {
          '/': (_) => const Scaffold(
            body: Column(
              children: [
                EngageSensitive(child: SizedBox(width: 300, height: 100)),
                TextField(key: Key('field')),
              ],
            ),
          ),
        }),
      );
      await tester.tapAt(const Offset(400, 50));
      await tester.tap(find.byKey(const Key('field')));
      await tester.pump(const Duration(seconds: 2));
      await engage.replay!.buffer.flush();
      final events = transport.events();
      expect(named(events, 'tap'), hasLength(1));
      expect(named(events, 'focus'), hasLength(1));
      engage.dispose();
    },
  );

  testWidgets(
    'going to the background is marked and sends what has been recorded so far',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {'/': (_) => const Scaffold(body: SizedBox.expand())}),
      );
      await tester.pump(const Duration(seconds: 1));
      engage.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 50));
      expect(transport.chunks, isNotEmpty);
      expect(named(transport.events(), 'bg'), hasLength(1));
      engage.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await engage.replay!.buffer.flush();
      engage.dispose();
    },
  );

  testWidgets('a server with replay turned off ends the recording', (
    tester,
  ) async {
    final (engage, transport) = await start(
      replay: const ReplayConfig(chunkEvents: 1),
    );
    transport.replayStatus = 403;
    await tester.pumpWidget(
      app(engage, {'/': (_) => const Scaffold(body: SizedBox.expand())}),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(seconds: 1));
    await tester.tapAt(const Offset(20, 20));
    await tester.pump(const Duration(seconds: 1));
    await engage.replay!.buffer.flush();
    final posts = transport.chunks.length;
    await tester.tapAt(const Offset(30, 30));
    await tester.pump(const Duration(seconds: 1));
    await engage.replay!.buffer.flush();
    expect(transport.chunks.length, posts);
    expect(engage.replay!.buffer.recording, false);
    engage.dispose();
  });

  testWidgets(
    'replay turns insights on by itself, and neither runs when not configured',
    (tester) async {
      final (withReplay, _) = await start();
      expect(withReplay.insights, isNotNull);
      withReplay.dispose();
      final (plain, transport) = await start(replay: null);
      expect(plain.insights, isNull);
      expect(plain.replay, isNull);
      await tester.pumpWidget(
        app(plain, {'/': (_) => const Scaffold(body: SizedBox.expand())}),
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(seconds: 2));
      expect(transport.chunks, isEmpty);
      plain.dispose();
    },
  );

  testWidgets(
    'withdrawing consent or forgetting the person throws away what was recorded',
    (tester) async {
      final (engage, transport) = await start(
        replay: const ReplayConfig(chunkInterval: Duration(hours: 1)),
      );
      await tester.pumpWidget(
        app(engage, {'/': (_) => const Scaffold(body: SizedBox.expand())}),
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(seconds: 1));
      await engage.setConsent(ConsentState.denied);
      await engage.replay!.buffer.flush();
      expect(transport.chunks, isEmpty);
      await engage.forget();
      await engage.replay!.buffer.flush();
      expect(transport.chunks, isEmpty);
      engage.dispose();
    },
  );
}
