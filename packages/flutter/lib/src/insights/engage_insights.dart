import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:ft_engage_core/ft_engage_core.dart';

import '../ft_engage.dart';
import 'engage_marker.dart';

const _tapSlop = 18.0;
const _tapTime = Duration(milliseconds: 500);

class _Touch {
  _Touch(this.start, this.at);

  final Offset start;
  final DateTime at;
  bool moved = false;
}

class TapReading {
  const TapReading({this.dead = true, this.target, this.sensitive = false});

  final bool dead;
  final String? target;
  final bool sensitive;
}

bool _handlesTouch(RenderObject target) =>
    target is RenderEditable ||
    (target is RenderSemanticsAnnotations &&
        (target.properties.onTap != null ||
            target.properties.onLongPress != null)) ||
    (target is RenderMouseRegion &&
        target.cursor == SystemMouseCursors.click) ||
    (target is RenderSemanticsGestureHandler &&
        (target.onTap != null ||
            target.onLongPress != null ||
            target.onHorizontalDragUpdate != null ||
            target.onVerticalDragUpdate != null));

TapReading readTap(HitTestResult result) {
  var dead = true;
  String? target;
  for (final entry in result.path) {
    final object = entry.target;
    if (object is RenderEngageMarker) {
      if (object.kind == MarkerKind.sensitive) {
        return const TapReading(sensitive: true);
      }
      target ??= object.id;
      if (object.interactive) dead = false;
    } else if (object is RenderObject && _handlesTouch(object)) {
      dead = false;
    }
  }
  return TapReading(dead: dead, target: target);
}

class EngageInsights extends StatefulWidget {
  const EngageInsights({super.key, required this.engage, required this.child});

  final FtEngage engage;
  final Widget child;

  @override
  State<EngageInsights> createState() => _EngageInsightsState();
}

class _EngageInsightsState extends State<EngageInsights> {
  final Map<int, _Touch> _touches = {};
  bool _multi = false;

  InsightsRecorder? get _recorder => widget.engage.insights;

  void _down(PointerDownEvent event) {
    if (_touches.isNotEmpty) {
      _multi = true;
    }
    _touches[event.pointer] = _Touch(event.position, DateTime.now());
  }

  void _move(PointerMoveEvent event) {
    final touch = _touches[event.pointer];
    if (touch != null && (event.position - touch.start).distance > _tapSlop) {
      touch.moved = true;
    }
  }

  void _up(PointerUpEvent event) {
    final touch = _touches.remove(event.pointer);
    final recorder = _recorder;
    final wasMulti = _multi;
    if (_touches.isEmpty) _multi = false;
    if (touch == null || recorder == null || wasMulti || touch.moved) return;
    if (DateTime.now().difference(touch.at) > _tapTime) return;
    final size = MediaQuery.maybeSizeOf(context);
    if (size == null) return;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      event.position,
      View.of(context).viewId,
    );
    final reading = readTap(result);
    if (reading.sensitive) return;
    recorder.tap(
      TapSample(
        x: event.position.dx,
        y: event.position.dy,
        viewportWidth: size.width,
        viewportHeight: size.height,
        dead: reading.dead,
        target: reading.target,
      ),
    );
  }

  void _cancel(PointerCancelEvent event) {
    _touches.remove(event.pointer);
    if (_touches.isEmpty) _multi = false;
  }

  bool _scrolled(ScrollNotification notification) {
    final metrics = notification.metrics;
    if (notification.depth == 0 &&
        metrics.axis == Axis.vertical &&
        metrics.maxScrollExtent > 0) {
      final fraction =
          (metrics.pixels + metrics.viewportDimension) /
          (metrics.maxScrollExtent + metrics.viewportDimension);
      _recorder?.scroll(fraction);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_recorder == null) return widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _cancel,
      child: NotificationListener<ScrollNotification>(
        onNotification: _scrolled,
        child: widget.child,
      ),
    );
  }
}
