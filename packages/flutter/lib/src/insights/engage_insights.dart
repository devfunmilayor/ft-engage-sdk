import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:ft_engage_core/ft_engage_core.dart';

import '../ft_engage.dart';
import 'engage_marker.dart';
import 'form_watcher.dart';
import 'response_watch.dart';

const _tapSlop = 18.0;
const _tapTime = Duration(milliseconds: 500);

class _Touch {
  _Touch(this.start, this.at, this.baseline);

  final Offset start;
  final DateTime at;
  final _Baseline baseline;
  bool moved = false;
}

class _Baseline {
  const _Baseline({
    required this.routes,
    required this.scrolls,
    required this.focus,
    required this.frames,
    required this.ambient,
  });

  final int routes;
  final int scrolls;
  final FocusNode? focus;
  final int frames;
  final bool ambient;
}

class TapReading {
  const TapReading({
    this.dead = true,
    this.target,
    this.sensitive = false,
    this.editable = false,
  });

  final bool editable;
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
  var editable = false;
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
      if (object is RenderEditable) editable = true;
    }
  }
  return TapReading(dead: dead, target: target, editable: editable);
}

class EngageInsights extends StatefulWidget {
  const EngageInsights({
    super.key,
    required this.engage,
    required this.child,
    this.responseWindow = const Duration(milliseconds: 400),
  });

  final FtEngage engage;
  final Widget child;
  final Duration responseWindow;

  @override
  State<EngageInsights> createState() => _EngageInsightsState();
}

class _EngageInsightsState extends State<EngageInsights> {
  final Map<int, _Touch> _touches = {};
  final ResponseWatch _watch = ResponseWatch();
  final Set<Timer> _pending = {};
  bool _multi = false;
  int _scrollEpoch = 0;

  FormWatcher? _forms;

  @override
  void initState() {
    super.initState();
    final recorder = widget.engage.insights;
    if (recorder != null) {
      _watch.install();
      if (recorder.config.forms) {
        _forms = FormWatcher(
          track: (name, {props = const {}}) => widget.engage.client.track(
            name,
            props: props,
            screen: recorder.screen,
          ),
        )..start();
      }
    }
  }

  @override
  void dispose() {
    for (final timer in _pending) {
      timer.cancel();
    }
    _forms?.stop();
    _watch.uninstall();
    super.dispose();
  }

  InsightsRecorder? get _recorder => widget.engage.insights;

  void _down(PointerDownEvent event) {
    if (_touches.isNotEmpty) {
      _multi = true;
    }
    _touches[event.pointer] = _Touch(
      event.position,
      DateTime.now(),
      _Baseline(
        routes: widget.engage.navigationEpoch,
        scrolls: _scrollEpoch,
        focus: FocusManager.instance.primaryFocus,
        frames: _watch.frames,
        ambient: _watch.ambient(),
      ),
    );
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
    if (reading.editable) widget.engage.replay?.mark('focus');
    TapSample sample(bool dead) => TapSample(
      x: event.position.dx,
      y: event.position.dy,
      viewportWidth: size.width,
      viewportHeight: size.height,
      dead: dead,
      target: reading.target,
    );
    if (!reading.dead) {
      recorder.tap(sample(false));
      return;
    }
    _confirmDead(recorder, sample, touch.baseline);
  }

  void _confirmDead(
    InsightsRecorder recorder,
    TapSample Function(bool) sample,
    _Baseline before,
  ) {
    final engage = widget.engage;
    late final Timer timer;
    timer = Timer(widget.responseWindow, () {
      _pending.remove(timer);
      final responded =
          engage.navigationEpoch != before.routes ||
          _scrollEpoch != before.scrolls ||
          !identical(FocusManager.instance.primaryFocus, before.focus) ||
          (!before.ambient && _watch.changedSince(before.frames));
      recorder.tap(sample(!responded));
    });
    _pending.add(timer);
  }

  void _cancel(PointerCancelEvent event) {
    _touches.remove(event.pointer);
    if (_touches.isEmpty) _multi = false;
  }

  bool _scrolled(Notification notification) {
    if (notification is ScrollUpdateNotification) _scrollEpoch += 1;
    final ScrollMetrics? metrics = switch (notification) {
      ScrollNotification() when notification.depth == 0 => notification.metrics,
      ScrollMetricsNotification() => notification.metrics,
      _ => null,
    };
    if (metrics == null ||
        metrics.axis != Axis.vertical ||
        metrics.maxScrollExtent <= 0) {
      return false;
    }
    final content = metrics.maxScrollExtent + metrics.viewportDimension;
    if (notification is ScrollNotification) {
      _recorder?.scroll(
        (metrics.pixels + metrics.viewportDimension) / content,
        offset: metrics.pixels,
        contentHeight: content,
      );
    } else {
      _recorder?.metrics(offset: metrics.pixels, contentHeight: content);
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
      child: NotificationListener<Notification>(
        onNotification: _scrolled,
        child: widget.child,
      ),
    );
  }
}
