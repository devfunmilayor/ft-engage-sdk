import 'dart:async';

import 'package:ft_engage_core/ft_engage_core.dart';

import 'layout_snapshot.dart';

typedef LayoutCapture = LayoutSnapshot? Function(int maxNodes);

class ReplayRecorder extends InsightsListener {
  ReplayRecorder({
    required this.buffer,
    LayoutCapture? capture,
    this.settle = const Duration(milliseconds: 350),
    this.afterTap = const Duration(milliseconds: 600),
  }) : _capture = capture ?? ((maxNodes) => captureLayout(maxNodes: maxNodes));

  final ReplayBuffer buffer;
  final LayoutCapture _capture;
  final Duration settle;
  final Duration afterTap;
  Timer? _timer;
  double _offset = 0;
  double _content = 0;
  double _sentOffset = -1000;
  DateTime? _lastScroll;

  @override
  void sessionStarted(String sid) => buffer.session(sid);

  @override
  void screenChanged(String name) {
    _offset = 0;
    _content = 0;
    _sentOffset = -1000;
    buffer.screen(name);
    schedule(settle);
  }

  @override
  void tapped(TapRecord tap) {
    buffer.tap(tap.x.round(), tap.y.round(), dead: tap.dead, rage: tap.rage);
    schedule(afterTap);
  }

  @override
  void scrolled(double offset, double contentHeight) {
    _offset = offset;
    _content = contentHeight;
    final now = DateTime.now();
    final last = _lastScroll;
    if ((last == null ||
            now.difference(last) >= buffer.config.scrollInterval) &&
        (offset - _sentOffset).abs() >= 20) {
      _lastScroll = now;
      _sentOffset = offset;
      buffer.scroll(offset.round(), contentHeight: contentHeight.round());
    }
    schedule(settle);
  }

  void mark(String kind) => buffer.mark(kind);

  void schedule(Duration delay) {
    if (!buffer.recording) return;
    _timer?.cancel();
    _timer = Timer(delay, _take);
  }

  void _take() {
    if ((_offset - _sentOffset).abs() >= 1 && _content > 0) {
      _sentOffset = _offset;
      buffer.scroll(_offset.round(), contentHeight: _content.round());
    }
    if (!buffer.wantSnapshot()) return;
    final snapshot = _capture(buffer.config.maxNodes);
    if (snapshot == null) return;
    buffer.snapshot(
      width: snapshot.width,
      height: snapshot.height,
      scrollOffset: _offset.round(),
      nodes: snapshot.nodes,
    );
  }

  void dispose() {
    _timer?.cancel();
    buffer.dispose();
  }
}
