import 'package:flutter/rendering.dart';

import 'engage_marker.dart';

class TapLabel {
  const TapLabel({this.label, this.role, this.explicit = false});

  final String? label;
  final String? role;
  final bool explicit;
}

bool _glyphOnly(String text) =>
    text.runes.every((r) => (r >= 0xE000 && r <= 0xF8FF) || r > 0xF0000);

TapLabel readLabel(RenderSemanticsAnnotations node) {
  final p = node.properties;
  final given = (p.label ?? p.tooltip)?.trim();
  if (p.onTap == null &&
      p.button != true &&
      p.toggled == null &&
      p.checked == null &&
      p.link != true &&
      p.textField != true &&
      (given == null || given.isEmpty)) {
    return const TapLabel();
  }
  final role = p.textField == true
      ? 'field'
      : (p.toggled != null || p.checked != null)
      ? 'toggle'
      : p.link == true
      ? 'link'
      : p.button == true
      ? 'button'
      : null;
  if (given != null && given.isNotEmpty) {
    return TapLabel(label: given, role: role, explicit: true);
  }
  if (role == null || role == 'field') return TapLabel(role: role);
  final words = <String>[];
  _collect(node, words, 0);
  return TapLabel(label: words.isEmpty ? null : words.join(' '), role: role);
}

void _collect(RenderObject object, List<String> out, int depth) {
  if (depth > 30 || out.length >= 3) return;
  if (object is RenderEngageMarker && object.kind == MarkerKind.sensitive) {
    return;
  }
  if (object is RenderEditable) return;
  if (object is RenderParagraph) {
    final text = object.text.toPlainText().trim();
    if (text.isNotEmpty && !_glyphOnly(text)) out.add(text);
    return;
  }
  object.visitChildren((child) => _collect(child, out, depth + 1));
}
