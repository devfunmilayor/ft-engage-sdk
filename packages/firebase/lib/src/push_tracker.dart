import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';

typedef PushTrack =
    Future<void> Function(String name, {Map<String, Object?> props});

/// Where notification messages come from: the payload `data` of each one.
abstract interface class PushMessages {
  /// Messages that arrive while the app is in the foreground.
  Stream<Map<String, Object?>> get received;

  /// Messages whose notification the person tapped while the app was running
  /// in the background.
  Stream<Map<String, Object?>> get opened;

  /// The message whose notification launched the app, if any.
  Future<Map<String, Object?>?> launchedBy();
}

class FirebasePushMessages implements PushMessages {
  FirebasePushMessages({FirebaseMessaging? messaging}) : _messaging = messaging;

  final FirebaseMessaging? _messaging;

  @override
  Stream<Map<String, Object?>> get received =>
      FirebaseMessaging.onMessage.map((m) => m.data);

  @override
  Stream<Map<String, Object?>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Future<Map<String, Object?>?> launchedBy() async =>
      (await (_messaging ?? FirebaseMessaging.instance).getInitialMessage())
          ?.data;
}

/// Reports what happens to FT.Engage notifications on this device.
///
/// A notification that arrives while the app is open is sent as
/// `push.received`, and one the person taps is sent as `push.opened`, each
/// with the `send` it belongs to. FT.Engage counts them as delivered and read
/// on the campaign, so the console shows opens for push like it does for
/// email. Notifications from other senders, and the silent checks FT.Engage
/// uses to estimate uninstalls, are ignored. An open is reported once even
/// if the platform announces it twice.
class PushTracker {
  PushTracker({required PushTrack track, PushMessages? messages})
    : _track = track,
      _messages = messages ?? FirebasePushMessages();

  final PushTrack _track;
  final PushMessages _messages;
  final Set<String> _opened = {};
  final List<StreamSubscription<Map<String, Object?>>> _subscriptions = [];

  /// Starts listening, and reports the notification that launched the app.
  Future<void> start() async {
    if (_subscriptions.isNotEmpty) return;
    _subscriptions
      ..add(_messages.received.listen((d) => _report('push.received', d)))
      ..add(_messages.opened.listen((d) => _report('push.opened', d)));
    try {
      final first = await _messages.launchedBy();
      if (first != null) await _report('push.opened', first);
    } on Object {
      return;
    }
  }

  Future<void> stop() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _report(String name, Map<String, Object?> data) async {
    final send = sendOf(data);
    if (send == null) return;
    if (name == 'push.opened' && !_opened.add(send)) return;
    try {
      await _track(name, props: {'send': send});
    } on Object {
      return;
    }
  }

  /// The FT.Engage send a notification belongs to, or `null` when it is not
  /// one of ours or is a silent uninstall check.
  static String? sendOf(Map<String, Object?> data) {
    if (data.containsKey('probe')) return null;
    final id = data['stepId'];
    return id is String && id.isNotEmpty && id.length <= 64 ? id : null;
  }
}
