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

Widget app(
  FtEngage engage,
  Map<String, WidgetBuilder> routes, {
  RouteFactory? generate,
}) => MaterialApp(
  navigatorObservers: [engage.navigatorObserver],
  initialRoute: '/',
  routes: routes,
  onGenerateRoute: generate,
  builder: (context, child) => EngageInsights(engage: engage, child: child!),
);

Future<List<Map<String, dynamic>>> captured(
  FtEngage engage,
  Recording transport,
  WidgetTester tester,
) async {
  await tester.pump(const Duration(milliseconds: 500));
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
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(400, 500));
      final taps = named(await captured(engage, transport, tester), 'ui.tap');
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
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(
          find.byWidgetPredicate((w) => w is EngageTarget && w.id == 'hero'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tapAt(
        tester.getCenter(
          find.byWidgetPredicate(
            (w) => w is EngageTarget && w.id == 'promo_banner',
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('field')));
      final taps = named(await captured(engage, transport, tester), 'ui.tap');
      expect(taps, hasLength(3));
      expect(props(taps[0])['target'], 'hero');
      expect(props(taps[0])['dead'], true);
      expect(props(taps[1])['target'], 'promo_banner');
      expect(props(taps[1]).containsKey('dead'), false);
      expect(props(taps[2]).containsKey('dead'), false);
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
    expect(named(await captured(engage, transport, tester), 'ui.tap'), isEmpty);
    await tester.tap(find.text('Pay'));
    expect(
      named(await captured(engage, transport, tester), 'ui.tap'),
      hasLength(1),
    );
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
      final events = await captured(engage, transport, tester);
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
      final views = named(
        await captured(engage, transport, tester),
        'screen.viewed',
      );
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
      final events = await captured(engage, transport, tester);
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
      expect(await captured(engage, transport, tester), isEmpty);
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
      final views = named(
        await captured(engage, transport, tester),
        'screen.viewed',
      );
      expect(views.map((e) => e['screen']).toList(), ['Onboarding', 'Home']);
      engage.dispose();
    },
  );

  testWidgets('a tap that looks dead but changes something is not dead', (
    tester,
  ) async {
    final (engage, transport) = await start();
    final node = FocusNode();
    var flipped = false;
    await tester.pumpWidget(
      app(engage, {
        '/': (context) => StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: Column(
              children: [
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerUp: (_) => Navigator.of(context).pushNamed('/next'),
                  child: const SizedBox(
                    key: Key('nav'),
                    width: 200,
                    height: 60,
                  ),
                ),
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerUp: (_) => setState(() => flipped = !flipped),
                  child: SizedBox(
                    key: const Key('state'),
                    width: 200,
                    height: 60,
                    child: Text(flipped ? 'on' : 'off'),
                  ),
                ),
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerUp: (_) => node.requestFocus(),
                  child: Focus(
                    focusNode: node,
                    child: const SizedBox(
                      key: Key('focus'),
                      width: 200,
                      height: 60,
                    ),
                  ),
                ),
                const SizedBox(key: Key('plain'), width: 200, height: 60),
              ],
            ),
          ),
        ),
        '/next': (_) => const Scaffold(body: Text('next')),
      }),
    );
    await tester.tap(find.byKey(const Key('state')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('focus')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('plain')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const Key('nav')));
    await tester.pumpAndSettle();
    final taps = named(await captured(engage, transport, tester), 'ui.tap');
    expect(taps, hasLength(4));
    expect(taps.map((e) => props(e).containsKey('dead')).toList(), [
      false,
      false,
      true,
      false,
    ]);
    engage.dispose();
  });

  testWidgets('a screen that is always animating cannot excuse a dead tap', (
    tester,
  ) async {
    final (engage, transport) = await start();
    await tester.pumpWidget(
      app(engage, {
        '/': (_) => const Scaffold(
          body: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(key: Key('plain'), width: 300, height: 300),
            ],
          ),
        ),
      }),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.tap(find.byKey(const Key('plain')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    final taps = named(await captured(engage, transport, tester), 'ui.tap');
    expect(taps, hasLength(1));
    expect(props(taps.single)['dead'], true);
    engage.dispose();
  });

  testWidgets('ids in route names are folded into one screen', (tester) async {
    final (engage, transport) = await start();
    await tester.pumpWidget(
      app(
        engage,
        {
          '/': (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  Navigator.of(context).pushNamed('/order/8841?tab=2'),
              child: const Text('Go'),
            ),
          ),
        },
        generate: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('order')),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    final views = named(
      await captured(engage, transport, tester),
      'screen.viewed',
    );
    expect(views.map((e) => e['screen']).toList(), ['/', '/order/:id']);
    engage.dispose();
  });

  testWidgets(
    'taps on a long page carry the scroll offset and the page height',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {
          '/': (_) => Scaffold(
            body: ListView(
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(
                    height: 100,
                    child: TextButton(onPressed: () {}, child: Text('row $i')),
                  ),
              ],
            ),
          ),
        }),
      );
      await tester.pump();
      await tester.tap(find.text('row 0'));
      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      await tester.tap(find.text('row 10'));
      final taps = named(await captured(engage, transport, tester), 'ui.tap');
      expect(taps, hasLength(2));
      expect(props(taps[0])['so'], 0);
      expect(props(taps[0])['ch'], 4000);
      expect(props(taps[1])['so'], greaterThan(800));
      expect(props(taps[1])['ch'], 4000);
      engage.dispose();
    },
  );

  testWidgets(
    'scroll depth left behind by a killed app is sent when the app starts again',
    (tester) async {
      final store = MemoryStore();
      await store.write(
        'ft_engage.insights.pending',
        jsonEncode({
          'screen': '/feed',
          'sid': 's1234abcd',
          'depth': 71,
          'at': '2026-11-20T10:00:00.000Z',
        }),
      );
      final transport = Recording();
      final engage = await FtEngage.init(
        publicKey: key,
        endpoint: Uri.parse('https://api.example.com'),
        transport: transport,
        storage: store,
        insights: const InsightsConfig(),
        observeLifecycle: false,
        flushInterval: null,
        platformOverride: 'android',
      );
      await engage.flush();
      final depth = transport.events
          .where((e) => e['name'] == 'ui.scroll_depth')
          .single;
      expect(depth['screen'], '/feed');
      expect(depth['at'], '2026-11-20T10:00:00.000Z');
      expect(props(depth), {
        'sid': 's1234abcd',
        'depth': 71,
        'recovered': true,
      });
      expect(await store.read('ft_engage.insights.pending'), isNull);
      engage.dispose();
    },
  );
}
