import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';
import 'package:ft_engage_flutter/src/insights/form_watcher.dart';

Widget form(Map<String, FocusNode> nodes) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            focusNode: nodes['email'],
            controller: TextEditingController(text: 'star@yopmail.com'),
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            focusNode: nodes['password'],
            controller: TextEditingController(text: 'hunter2hunter2'),
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          TextField(
            focusNode: nodes['pin'],
            controller: TextEditingController(text: 'abcd'),
            decoration: const InputDecoration(labelText: 'Transaction PIN'),
          ),
          TextField(
            focusNode: nodes['phone'],
            controller: TextEditingController(text: 'ph'),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Quantity'),
          ),
          TextField(
            focusNode: nodes['note'],
            controller: TextEditingController(text: '4111 1111 1111 1111'),
            decoration: const InputDecoration(labelText: 'Note'),
          ),
          TextField(
            focusNode: nodes['name'],
            controller: TextEditingController(text: 'Ada 08012345678'),
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          EngageSensitive(
            child: TextField(
              controller: TextEditingController(text: 'sensitive-box'),
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
          ),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('only safe boxes give up their text, and never by default', (
    tester,
  ) async {
    await tester.pumpWidget(form({}));
    final off = jsonEncode(captureLayout()!.nodes);
    for (final value in ['star@yopmail', 'hunter2', 'abcd', '4111', 'Ada']) {
      expect(off.contains(value), false, reason: value);
    }
    final on = captureLayout(captureText: true)!;
    final text = jsonEncode(on.nodes);
    expect(text.contains('star@yopmail.com'), true);
    expect(text.contains('Ada •••••••••••'), true);
    for (final secret in [
      'hunter2',
      'abcd',
      '4111',
      '08012345678',
      'sensitive-box',
      'ph',
    ]) {
      expect(text.contains(secret), false, reason: secret);
    }
    final strings = on.nodes.where((n) => n.length == 6 && n[5] is String);
    expect(strings.map((n) => n[0]).toSet(), {'f'});
    expect(strings.length, 2);
    expect(on.nodes.where((n) => n[0] == 'm'), hasLength(1));
  });

  testWidgets(
    'leaving a box reports that it was filled, how long and never what was typed',
    (tester) async {
      final nodes = {
        'email': FocusNode(),
        'password': FocusNode(),
        'pin': FocusNode(),
        'phone': FocusNode(),
        'note': FocusNode(),
        'name': FocusNode(),
      };
      final seen = <Map<String, Object?>>[];
      final names = <String>[];
      final watcher = FormWatcher(
        track: (name, {props = const {}}) async {
          names.add(name);
          seen.add(props);
        },
      )..start();
      addTearDown(watcher.stop);
      await tester.pumpWidget(form(nodes));
      nodes['email']!.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      nodes['password']!.requestFocus();
      await tester.pump();
      nodes['pin']!.requestFocus();
      await tester.pump();
      nodes['name']!.requestFocus();
      await tester.pump();
      nodes['name']!.unfocus();
      await tester.pump();
      expect(seen.map((p) => p['field']), [
        'email',
        'password',
        'transaction_pin',
        'full_name',
      ]);
      expect(seen.map((p) => p['masked']), [false, true, true, false]);
      expect(names.toSet(), {'form.field'});
      expect(seen.every((p) => p['state'] == 'filled'), true);
      expect(seen.first['chars'], '13+');
      expect(seen.every((p) => p['ms'] is int && (p['ms'] as int) >= 0), true);
      final wire = jsonEncode(seen);
      for (final value in ['star@yopmail', 'hunter2', 'abcd', 'Ada']) {
        expect(wire.contains(value), false, reason: value);
      }
      expect(SystemChannels.textInput, isNotNull);
    },
  );
}
