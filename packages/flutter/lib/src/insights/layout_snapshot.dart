import 'package:flutter/rendering.dart';

import 'engage_marker.dart';

class LayoutSnapshot {
  const LayoutSnapshot(this.width, this.height, this.nodes);

  final int width;
  final int height;
  final List<List<Object>> nodes;
}

int _clamp(double value) => value.round().clamp(-100000, 100000);

int _argb(Color color) => color.toARGB32();

bool _tappable(RenderObject object) =>
    (object is RenderSemanticsGestureHandler &&
        (object.onTap != null || object.onLongPress != null)) ||
    (object is RenderSemanticsAnnotations &&
        (object.properties.onTap != null ||
            object.properties.onLongPress != null)) ||
    (object is RenderMouseRegion && object.cursor == SystemMouseCursors.click);

Color? _coloredBoxColor(RenderObject object) {
  try {
    final value = (object as dynamic).color;
    return value is Color && value.a > 0 ? value : null;
  } on Object {
    return null;
  }
}

List<Object>? _node(String kind, Rect rect, [Color? color]) {
  final left = _clamp(rect.left);
  final top = _clamp(rect.top);
  final width = _clamp(rect.width).clamp(0, 100000);
  final height = _clamp(rect.height).clamp(0, 100000);
  if (width < 1 || height < 1) return null;
  return [kind, left, top, width, height, if (color != null) _argb(color)];
}

LayoutSnapshot? captureLayout({int maxNodes = 250}) {
  final views = RendererBinding.instance.renderViews;
  if (views.isEmpty) return null;
  final view = views.first;
  final size = view.size;
  if (size.isEmpty) return null;
  final screen = Offset.zero & size;
  final nodes = <List<Object>>[];

  void add(List<Object>? node) {
    if (node == null || nodes.length >= maxNodes) return;
    if (nodes.isNotEmpty) {
      final last = nodes.last;
      if (last.length == node.length) {
        var same = true;
        for (var i = 0; i < node.length; i++) {
          if (last[i] != node[i]) same = false;
        }
        if (same) return;
      }
    }
    nodes.add(node);
  }

  void visit(RenderObject object) {
    if (nodes.length >= maxNodes) return;
    if (object is RenderOffstage && object.offstage) return;
    if (object is RenderOpacity && object.opacity == 0) return;
    if (object is RenderAnimatedOpacity && object.opacity.value == 0) return;
    if (object is RenderBox && object.hasSize && object.attached) {
      Rect rect;
      try {
        rect = MatrixUtils.transformRect(
          object.getTransformTo(null),
          Offset.zero & object.size,
        );
      } on Object {
        return;
      }
      if (!rect.overlaps(screen)) return;
      if (object is RenderEngageMarker && object.kind == MarkerKind.sensitive) {
        add(_node('m', rect.intersect(screen)));
        return;
      }
      if (object is RenderParagraph) {
        if (object.text.toPlainText().isNotEmpty) add(_node('t', rect));
      } else if (object is RenderEditable) {
        add(_node('f', rect));
      } else if (object is RenderImage) {
        add(_node('i', rect));
      } else if (object is RenderPhysicalShape && object.color.a > 0) {
        add(_node('x', rect, object.color));
      } else if (object is RenderPhysicalModel && object.color.a > 0) {
        add(_node('x', rect, object.color));
      } else if (object.runtimeType.toString() == '_RenderColoredBox') {
        final color = _coloredBoxColor(object);
        if (color != null) add(_node('x', rect, color));
      } else if (object is RenderDecoratedBox) {
        final decoration = object.decoration;
        if (decoration is BoxDecoration) {
          if (decoration.image != null) {
            add(_node('i', rect));
          } else if (decoration.color != null && decoration.color!.a > 0) {
            add(_node('x', rect, decoration.color));
          }
        }
      }
      if (_tappable(object)) add(_node('b', rect));
    } else if (_tappable(object)) {
      return;
    }
    object.visitChildren(visit);
  }

  visit(view);
  return LayoutSnapshot(size.width.round(), size.height.round(), nodes);
}
