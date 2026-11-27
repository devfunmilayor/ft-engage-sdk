import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:ft_engage_core/ft_engage_core.dart';

import 'layout_snapshot.dart';

typedef FieldTrack =
    Future<void> Function(String name, {Map<String, Object?> props});

class FormWatcher {
  FormWatcher({required this.track, this.onFocus});

  final FieldTrack track;
  final VoidCallback? onFocus;
  EditableTextState? _state;
  Element? _element;
  DateTime? _since;
  bool _running = false;

  void start() {
    if (_running) return;
    _running = true;
    FocusManager.instance.addListener(_changed);
  }

  void stop() {
    if (!_running) return;
    _running = false;
    FocusManager.instance.removeListener(_changed);
    _leave();
  }

  (EditableTextState, Element)? _stateOf(FocusNode? node) {
    final context = node?.context;
    if (context is! Element) return null;
    (EditableTextState, Element)? found;
    void look(Element e) {
      if (found == null &&
          e is StatefulElement &&
          e.state is EditableTextState) {
        found = (e.state as EditableTextState, e);
      }
    }

    look(context);
    if (found == null) {
      context.visitAncestorElements((e) {
        look(e);
        return found == null;
      });
    }
    return found;
  }

  void _changed() {
    final next = _stateOf(FocusManager.instance.primaryFocus);
    if (identical(next?.$1, _state)) return;
    _leave();
    if (next != null) {
      _state = next.$1;
      _element = next.$2;
      _since = DateTime.now();
      onFocus?.call();
    }
  }

  void _leave() {
    final state = _state;
    final element = _element;
    final since = _since;
    _state = null;
    _element = null;
    _since = null;
    if (state == null || since == null || !state.mounted || element == null) {
      return;
    }
    final facts = factsOf(element, state.widget);
    final length = facts.text.trim().length;
    final label = facts.label.isEmpty
        ? (state.widget.autofillHints?.firstOrNull ?? '')
        : facts.label;
    unawaited(
      track(
        'form.field',
        props: {
          'field': FieldPolicy.slug(label),
          'state': length == 0 ? 'empty' : 'filled',
          'chars': FieldPolicy.lengthBucket(length),
          'ms': DateTime.now()
              .difference(since)
              .inMilliseconds
              .clamp(0, 600000),
          'masked': FieldPolicy.sensitive(facts),
        },
      ).catchError((Object _) {}),
    );
  }
}
