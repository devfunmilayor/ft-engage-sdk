import 'dart:async';
import 'dart:convert';

import 'clock.dart';
import 'storage.dart';

enum InAppLayout { modal, banner }

/// A message to show inside the app, as the server sent it.
class InAppMessage {
  const InAppMessage({
    required this.id,
    required this.triggerEvent,
    required this.layout,
    required this.title,
    required this.body,
    this.triggerScreen,
    this.buttonLabel,
    this.actionUrl,
    this.delay = Duration.zero,
    this.maxShows = 1,
    this.minHoursBetween = 24,
    this.updatedAt,
  });

  final String id;
  final String triggerEvent;
  final String? triggerScreen;
  final InAppLayout layout;
  final String title;
  final String body;
  final String? buttonLabel;
  final String? actionUrl;
  final Duration delay;
  final int maxShows;
  final int minHoursBetween;
  final DateTime? updatedAt;

  static InAppMessage? tryParse(Object? raw) {
    try {
      final j = raw! as Map<String, dynamic>;
      final trigger = j['trigger'] as Map<String, dynamic>;
      return InAppMessage(
        id: j['id'] as String,
        triggerEvent: trigger['event'] as String,
        triggerScreen: trigger['screen'] as String?,
        layout: j['layout'] == 'banner'
            ? InAppLayout.banner
            : InAppLayout.modal,
        title: j['title'] as String,
        body: j['body'] as String,
        buttonLabel: j['buttonLabel'] as String?,
        actionUrl: j['actionUrl'] as String?,
        delay: Duration(seconds: (j['delaySeconds'] as int? ?? 0).clamp(0, 60)),
        maxShows: (j['maxShows'] as int? ?? 1).clamp(1, 20),
        minHoursBetween: (j['minHoursBetween'] as int? ?? 24).clamp(0, 720),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
      );
    } on Object {
      return null;
    }
  }
}

typedef InAppTrack =
    Future<void> Function(String name, {Map<String, Object?> props});

/// Decides on the device which in-app message to show and when.
///
/// The live messages are fetched from the server and kept on the device, so
/// they still appear offline. When an event matches a message's trigger, and
/// the person has seen it fewer than `maxShows` times and not within
/// `minHoursBetween`, the message is offered on [due] after its delay. Only
/// one message is on screen at a time. What the person does is reported as
/// `inapp.shown`, `inapp.clicked` and `inapp.dismissed`.
class InAppEngine {
  InAppEngine({
    required KeyValueStore store,
    required Clock clock,
    required InAppTrack track,
    required Future<String?> Function() fetch,
    this.refreshEvery = const Duration(minutes: 5),
  }) : _store = store,
       _clock = clock,
       _track = track,
       _fetch = fetch;

  static const messagesKey = 'ft_engage.in_app.messages';
  static const historyKey = 'ft_engage.in_app.history';

  final KeyValueStore _store;
  final Clock _clock;
  final InAppTrack _track;
  final Future<String?> Function() _fetch;
  final Duration refreshEvery;
  final StreamController<InAppMessage> _due = StreamController.broadcast();

  List<InAppMessage> _messages = const [];
  Map<String, ({int shows, DateTime last})> _history = {};
  DateTime? _fetchedAt;
  String? _onScreen;
  bool _waiting = false;

  Stream<InAppMessage> get due => _due.stream;
  List<InAppMessage> get messages => List.unmodifiable(_messages);

  /// Reads the messages and history kept from earlier runs.
  Future<void> load() async {
    _messages = _parse(await _store.read(messagesKey)) ?? const [];
    try {
      final raw = await _store.read(historyKey);
      final Map<String, dynamic> json = raw == null
          ? const <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
      _history = {
        for (final e in json.entries)
          e.key: (
            shows: (e.value as Map<String, dynamic>)['shows'] as int,
            last: DateTime.parse(e.value['last'] as String),
          ),
      };
    } on Object {
      _history = {};
    }
  }

  /// Fetches the live messages, at most once per [refreshEvery] unless
  /// [force]d. A failed fetch keeps the messages already known.
  Future<void> refresh({bool force = false}) async {
    final now = _clock.now();
    final last = _fetchedAt;
    if (!force && last != null && now.difference(last) < refreshEvery) return;
    _fetchedAt = now;
    final body = await _fetch();
    final parsed = _parse(body);
    if (parsed == null) return;
    _messages = parsed;
    await _store.write(
      messagesKey,
      jsonEncode({'messages': jsonDecode(body!)['messages']}),
    );
  }

  /// Call for every tracked event. Offers at most one matching message.
  void onEvent(String name, String? screen) {
    if (name.startsWith('inapp.') || _onScreen != null || _waiting) return;
    final now = _clock.now();
    final candidates = [
      for (final m in _messages)
        if (m.triggerEvent == name &&
            (m.triggerScreen == null || m.triggerScreen == screen) &&
            _allowed(m, now))
          m,
    ]..sort((a, b) => (b.updatedAt ?? now).compareTo(a.updatedAt ?? now));
    if (candidates.isEmpty) return;
    final pick = candidates.first;
    _waiting = true;
    Future<void>.delayed(pick.delay, () {
      _waiting = false;
      if (_onScreen != null || _due.isClosed) return;
      _onScreen = pick.id;
      _due.add(pick);
    });
  }

  bool _allowed(InAppMessage m, DateTime now) {
    final seen = _history[m.id];
    if (seen == null) return true;
    if (seen.shows >= m.maxShows) return false;
    return now.difference(seen.last) >= Duration(hours: m.minHoursBetween);
  }

  /// The person saw [m]. Counts towards its limits.
  Future<void> shown(InAppMessage m) async {
    final seen = _history[m.id];
    _history[m.id] = (shows: (seen?.shows ?? 0) + 1, last: _clock.now());
    await _store.write(
      historyKey,
      jsonEncode({
        for (final e in _history.entries)
          e.key: {
            'shows': e.value.shows,
            'last': e.value.last.toIso8601String(),
          },
      }),
    );
    await _report('inapp.shown', m);
  }

  /// The person tapped the button of [m]. Frees the screen for the next one.
  Future<void> clicked(InAppMessage m) => _close('inapp.clicked', m);

  /// The person closed [m] without tapping. Frees the screen.
  Future<void> dismissed(InAppMessage m) => _close('inapp.dismissed', m);

  Future<void> _close(String name, InAppMessage m) async {
    if (_onScreen == m.id) _onScreen = null;
    await _report(name, m);
  }

  Future<void> _report(String name, InAppMessage m) async {
    try {
      await _track(name, props: {'message': m.id});
    } on Object {
      return;
    }
  }

  Future<void> forget() async {
    _messages = const [];
    _history = {};
    _onScreen = null;
    await _store.delete(messagesKey);
    await _store.delete(historyKey);
  }

  Future<void> dispose() => _due.close();

  List<InAppMessage>? _parse(String? body) {
    if (body == null) return null;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return [
        for (final raw in json['messages'] as List<dynamic>)
          ?InAppMessage.tryParse(raw),
      ];
    } on Object {
      return null;
    }
  }
}
