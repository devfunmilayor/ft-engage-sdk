import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

class Recording implements Transport {
  final List<Map<String, dynamic>> events = [];

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    if (url.path == '/v1/events') {
      events.addAll(
        ((jsonDecode(body) as Map)['events'] as List)
            .cast<Map<String, dynamic>>(),
      );
    }
    return const TransportResponse(200, '{}');
  }
}

const key = 'pk_test_abcdefghijklmnopqrstuvwxyz012345';

Future<(FtEngage, Recording)> start({
  InsightsConfig? config = const InsightsConfig(),
}) async {
  final transport = Recording();
  final engage = await FtEngage.init(
    publicKey: key,
    endpoint: Uri.parse('https://api.example.com'),
    transport: transport,
    storage: MemoryStore(),
    insights: config,
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

Future<List<Map<String, dynamic>>> captured(
  FtEngage engage,
  Recording transport,
) async {
  await engage.flush();
  return transport.events
      .where(
        (e) =>
            (e['name'] as String).startsWith('ui.') ||
            e['name'] == 'screen.viewed',
      )
      .toList();
}

List<Map<String, dynamic>> named(
  List<Map<String, dynamic>> events,
  String name,
) => events.where((e) => e['name'] == name).toList();

Map<String, dynamic> props(Map<String, dynamic> event) =>
    event['props'] as Map<String, dynamic>;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a tap on a button is a live tap and one on empty space is a dead tap',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {
          '/': (_) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('Buy')),
                const SizedBox(height: 300),
              ],
            ),
          ),
        }),
      );
      await tester.tap(find.text('Buy'));
      await tester.tapAt(const Offset(400, 500));
      final taps = named(await captured(engage, transport), 'ui.tap');
      expect(taps, hasLength(2));
      expect(props(taps[0]).containsKey('dead'), false);
      expect(props(taps[1])['dead'], true);
      expect(props(taps[1])['x'], 0.5);
      expect(props(taps[1])['vw'], 800);
      expect(taps.every((e) => e['screen'] == '/'), true);
      engage.dispose();
    },
  );

  testWidgets(
    'text fields and custom handlers count as live and a marker names the target',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {
          '/': (_) => Scaffold(
            body: Column(
              children: [
                const TextField(key: Key('field')),
                const EngageTarget(
                  id: 'promo_banner',
                  interactive: true,
                  child: SizedBox(width: 200, height: 60),
                ),
                const EngageTarget(
                  id: 'hero',
                  child: SizedBox(width: 200, height: 60),
                ),
              ],
            ),
          ),
        }),
      );
      await tester.tap(find.byKey(const Key('field')));
      await tester.tapAt(
        tester.getCenter(
          find.byWidgetPredicate(
            (w) => w is EngageTarget && w.id == 'promo_banner',
          ),
        ),
      );
      await tester.tapAt(
        tester.getCenter(
          find.byWidgetPredicate((w) => w is EngageTarget && w.id == 'hero'),
        ),
      );
      final taps = named(await captured(engage, transport), 'ui.tap');
      expect(taps, hasLength(3));
      expect(props(taps[0]).containsKey('dead'), false);
      expect(props(taps[1])['target'], 'promo_banner');
      expect(props(taps[1]).containsKey('dead'), false);
      expect(props(taps[2])['target'], 'hero');
      expect(props(taps[2])['dead'], true);
      engage.dispose();
    },
  );

  testWidgets('taps inside a sensitive area are not recorded at all', (
    tester,
  ) async {
    final (engage, transport) = await start();
    await tester.pumpWidget(
      app(engage, {
        '/': (_) => Scaffold(
          body: Column(
            children: [
              const EngageSensitive(child: SizedBox(width: 300, height: 100)),
              ElevatedButton(onPressed: () {}, child: const Text('Pay')),
            ],
          ),
        ),
      }),
    );
    await tester.tapAt(const Offset(100, 50));
    expect(named(await captured(engage, transport), 'ui.tap'), isEmpty);
    await tester.tap(find.text('Pay'));
    expect(named(await captured(engage, transport), 'ui.tap'), hasLength(1));
    engage.dispose();
  });

  testWidgets(
    'quick repeated taps are reported as one rage tap and drags are not taps',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {'/': (_) => const Scaffold(body: SizedBox.expand())}),
      );
      for (var i = 0; i < 4; i++) {
        await tester.tapAt(const Offset(200, 200));
      }
      await tester.dragFrom(const Offset(100, 300), const Offset(0, -150));
      final events = await captured(engage, transport);
      expect(named(events, 'ui.tap'), hasLength(4));
      final rage = named(events, 'ui.rage_tap');
      expect(rage, hasLength(1));
      expect(props(rage.single)['taps'], 3);
      engage.dispose();
    },
  );

  testWidgets(
    'named routes become screens with where the person came from, and unnamed or popup routes do not',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {
          '/': (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/signup'),
              child: const Text('Go'),
            ),
          ),
          '/signup': (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back'),
            ),
          ),
        }),
      );
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      showDialog<void>(
        context: tester.element(find.text('Go')),
        builder: (_) => const AlertDialog(title: Text('Hi')),
      );
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Hi'))).pop();
      await tester.pumpAndSettle();
      final views = named(await captured(engage, transport), 'screen.viewed');
      expect(views.map((e) => e['screen']).toList(), ['/', '/signup', '/']);
      expect(props(views[0]).containsKey('from'), false);
      expect(props(views[1])['from'], '/');
      expect(props(views[2])['from'], '/signup');
      engage.dispose();
    },
  );

  testWidgets(
    'scrolling a long page reports its deepest point when the person leaves it',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {
          '/': (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pushNamed('/next'),
                  child: const Text('Next'),
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
      await tester.fling(find.byType(ListView), const Offset(0, -20000), 5000);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      final events = await captured(engage, transport);
      final depth = named(events, 'ui.scroll_depth');
      expect(depth, hasLength(1));
      expect(depth.single['screen'], '/');
      expect(props(depth.single)['depth'], 100);
      expect(
        named(events, 'ui.tap').where((e) => e['screen'] == '/'),
        hasLength(1),
      );
      engage.dispose();
    },
  );

  testWidgets(
    'without an insights configuration nothing is captured and the screen call is harmless',
    (tester) async {
      final (engage, transport) = await start(config: null);
      await tester.pumpWidget(
        app(engage, {
          '/': (_) => Scaffold(
            body: ElevatedButton(onPressed: () {}, child: const Text('Buy')),
          ),
        }),
      );
      await tester.tap(find.text('Buy'));
      engage.screen('Manual');
      expect(await captured(engage, transport), isEmpty);
      engage.dispose();
    },
  );

  testWidgets(
    'the screen can be named by hand for apps that do not use named routes',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        MaterialApp(
          home: EngageInsights(
            engage: engage,
            child: const Scaffold(body: Text('x')),
          ),
        ),
      );
      engage.screen('Onboarding');
      engage.screen('Onboarding');
      engage.screen('Home');
      final views = named(await captured(engage, transport), 'screen.viewed');
      expect(views.map((e) => e['screen']).toList(), ['Onboarding', 'Home']);
      engage.dispose();
    },
  );
}
