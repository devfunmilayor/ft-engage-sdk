import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

enum MarkerKind { target, sensitive }

class EngageTarget extends SingleChildRenderObjectWidget {
  const EngageTarget({
    super.key,
    required this.id,
    this.interactive = false,
    super.child,
  });

  final String id;
  final bool interactive;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEngageMarker(MarkerKind.target, id, interactive);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderEngageMarker renderObject,
  ) {
    renderObject
      ..id = id
      ..interactive = interactive;
  }
}

class EngageSensitive extends SingleChildRenderObjectWidget {
  const EngageSensitive({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderEngageMarker(MarkerKind.sensitive, null, false);
}

class RenderEngageMarker extends RenderProxyBox {
  RenderEngageMarker(this.kind, this.id, this.interactive);

  final MarkerKind kind;
  String? id;
  bool interactive;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final hit = super.hitTest(result, position: position);
    if (!hit && size.contains(position)) {
      result.add(BoxHitTestEntry(this, position));
    }
    return hit;
  }
}
