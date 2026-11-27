import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ft_engage_firebase/ft_engage_firebase.dart';

const send = '6f1c2a4e-1b2c-4d3e-8f90-123456789abc';

class FakeMessages implements PushMessages {
  final StreamController<Map<String, Object?>> arrivals =
      StreamController.broadcast();
  final StreamController<Map<String, Object?>> taps =
      StreamController.broadcast();
  Map<String, Object?>? launch;
  Object? launchError;

  @override
  Stream<Map<String, Object?>> get received => arrivals.stream;

  @override
  Stream<Map<String, Object?>> get opened => taps.stream;

  @override
  Future<Map<String, Object?>?> launchedBy() async {
    if (launchError != null) throw launchError!;
    return launch;
  }
}

void main() {
  late FakeMessages messages;
  late List<(String, Map<String, Object?>)> sent;
  late PushTracker tracker;

  setUp(() {
    messages = FakeMessages();
    sent = [];
    tracker = PushTracker(
      messages: messages,
      track: (name, {props = const {}}) async => sent.add((name, props)),
    );
  });

  test(
    'arrivals and taps of FT.Engage pushes are reported with the send',
    () async {
      await tracker.start();
      messages.arrivals.add({'stepId': send});
      messages.taps.add({'stepId': send});
      await pumpEventQueue();
      expect(sent.map((e) => e.$1), ['push.received', 'push.opened']);
      expect(sent.map((e) => e.$2), [
        {'send': send},
        {'send': send},
      ]);
    },
  );

  test(
    'the notification that launched the app counts as opened once',
    () async {
      messages.launch = {'stepId': send};
      await tracker.start();
      messages.taps.add({'stepId': send});
      await pumpEventQueue();
      expect(sent.single.$1, 'push.opened');
      expect(sent.single.$2, {'send': send});
    },
  );

  test('other senders and uninstall checks are ignored', () async {
    await tracker.start();
    messages.arrivals.add({'campaign': 'someone else'});
    messages.arrivals.add({'probe': 'probe_inst_00000001'});
    messages.taps.add({'stepId': ''});
    messages.taps.add({'stepId': 42});
    await pumpEventQueue();
    expect(sent, isEmpty);
  });

  test('a failing launch lookup or track call never breaks the app', () async {
    messages.launchError = StateError('no firebase');
    final failing = PushTracker(
      messages: messages,
      track: (name, {props = const {}}) async => throw StateError('full'),
    );
    await failing.start();
    messages.taps.add({'stepId': send});
    await pumpEventQueue();
    await failing.stop();
  });

  test('stop ends listening', () async {
    await tracker.start();
    await tracker.stop();
    messages.taps.add({'stepId': send});
    await pumpEventQueue();
    expect(sent, isEmpty);
  });
}
