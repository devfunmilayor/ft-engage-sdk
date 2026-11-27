import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

class FeedTransport implements Transport, ReadTransport {
  FeedTransport(this.messages);

  final List<Map<String, Object?>> messages;
  final List<Map<String, dynamic>> events = [];

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    if (url.path == '/v1/events') {
      events.addAll(
        ((jsonDecode(body) as Map<String, dynamic>)['events'] as List<dynamic>)
            .cast<Map<String, dynamic>>(),
      );
    }
    return const TransportResponse(200, '{}');
  }

  @override
  Future<TransportResponse> get(Uri url, Map<String, String> headers) async =>
      TransportResponse(200, jsonEncode({'messages': messages}));

  List<(String, Object?)> reactions() => [
    for (final e in events)
      if ((e['name'] as String).startsWith('inapp.'))
        (e['name'] as String, (e['props'] as Map?)?['message']),
  ];
}

Map<String, Object?> message(String layout) => {
  'id': 'm1',
  'trigger': {'event': 'cart.opened'},
  'layout': layout,
  'title': 'Free delivery',
  'body': 'Order before 6pm.',
  'buttonLabel': 'Shop now',
  'actionUrl': 'myapp://shop',
  'delaySeconds': 0,
  'maxShows': 1,
  'minHoursBetween': 0,
};

final stores = <FtEngage, MemoryStore>{};

Future<List<(String, Object?)>> queued(
  WidgetTester tester,
  FtEngage engage,
) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  final store = stores[engage]!;
  return [
    for (final raw in await store.head(await store.length()))
      if ((jsonDecode(raw)['name'] as String).startsWith('inapp.'))
        (
          jsonDecode(raw)['name'] as String,
          (jsonDecode(raw)['props'] as Map?)?['message'],
        ),
  ];
}

Future<(FtEngage, FeedTransport, List<Uri>)> start(
  WidgetTester tester, {
  String layout = 'modal',
  bool enabled = true,
}) async {
  final transport = FeedTransport([message(layout)]);
  final opened = <Uri>[];
  late FtEngage engage;
  final store = MemoryStore();
  await tester.runAsync(() async {
    engage = await FtEngage.init(
      publicKey: 'pk_test_abcdefghijklmnopqrstuvwxyz012345',
      endpoint: Uri.parse('https://api.example.com'),
      transport: transport,
      storage: store,
      observeLifecycle: false,
      flushInterval: null,
      platformOverride: 'android',
      sessionTimeout: null,
      inAppMessages: enabled,
    );
    await engage.inApp?.refresh(force: true);
  });
  stores[engage] = store;
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          EngageInApp(engage: engage, onAction: opened.add, child: child!),
      home: const Scaffold(body: Text('Shop')),
    ),
  );
  return (engage, transport, opened);
}

Future<void> trigger(WidgetTester tester, FtEngage engage) async {
  await tester.runAsync(() async {
    await engage.track('cart.opened');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a card appears on its event and the button opens the link', (
    tester,
  ) async {
    final (engage, transport, opened) = await start(tester);
    expect(find.byKey(const Key('ft-in-app-m1')), findsNothing);
    await trigger(tester, engage);
    expect(find.text('Free delivery'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ft-in-app-action')));
    await tester.pumpAndSettle();
    expect(find.text('Free delivery'), findsNothing);
    expect(opened, [Uri.parse('myapp://shop')]);
    expect(await queued(tester, engage), [
      ('inapp.shown', 'm1'),
      ('inapp.clicked', 'm1'),
    ]);
    await trigger(tester, engage);
    expect(find.text('Free delivery'), findsNothing);
    engage.dispose();
  });

  testWidgets('tapping outside a card dismisses it', (tester) async {
    final (engage, transport, opened) = await start(tester);
    await trigger(tester, engage);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('Free delivery'), findsNothing);
    expect(opened, isEmpty);
    expect((await queued(tester, engage)).last, ('inapp.dismissed', 'm1'));
    engage.dispose();
  });

  testWidgets('a banner sits at the top and leaves the app usable', (
    tester,
  ) async {
    final (engage, _, _) = await start(tester, layout: 'banner');
    await trigger(tester, engage);
    expect(find.byKey(const Key('ft-in-app-barrier')), findsNothing);
    expect(tester.getTopLeft(find.text('Free delivery')).dy, lessThan(120));
    await tester.tap(find.byKey(const Key('ft-in-app-close')));
    await tester.pumpAndSettle();
    expect(find.text('Free delivery'), findsNothing);
    engage.dispose();
  });

  testWidgets('in-app messages can be turned off', (tester) async {
    final (engage, _, _) = await start(tester, enabled: false);
    expect(engage.inApp, isNull);
    await trigger(tester, engage);
    expect(find.text('Free delivery'), findsNothing);
    engage.dispose();
  });
}
