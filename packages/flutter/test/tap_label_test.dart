import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

import 'insights_test.dart' show app, captured, start;

void main() {
  testWidgets(
    'a tap carries what the person pressed, never what looks private',
    (tester) async {
      final (engage, transport) = await start();
      await tester.pumpWidget(
        app(engage, {
          '/': (_) => Scaffold(
            body: Column(
              children: [
                ElevatedButton(onPressed: () {}, child: const Text('Wallet')),
                ElevatedButton(onPressed: () {}, child: const Text('Pay £50')),
                IconButton(
                  tooltip: 'Compare rates',
                  onPressed: () {},
                  icon: const Icon(Icons.swap_horiz),
                ),
                ListTile(title: const Text('Ada Lovelace'), onTap: () {}),
                Switch(value: true, onChanged: (_) {}),
                EngageSensitive(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: const Text('Secret thing'),
                  ),
                ),
              ],
            ),
          ),
        }),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wallet'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Pay £50'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byIcon(Icons.swap_horiz));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Ada Lovelace'));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tap(find.text('Secret thing'));
      final taps = (await captured(engage, transport, tester))
          .where((e) => e['name'] == 'ui.tap')
          .map((e) => (e['props'] as Map))
          .toList();
      expect(taps.map((p) => [p['label'], p['role']]).toList(), [
        ['Wallet', 'button'],
        [null, 'button'],
        ['Compare rates', 'button'],
        [null, 'button'],
        [null, 'toggle'],
      ]);
      expect(taps.any((p) => '${p['label']}'.contains('Secret')), false);
    },
  );
}
