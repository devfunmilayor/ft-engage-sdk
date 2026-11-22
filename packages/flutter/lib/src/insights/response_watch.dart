import 'package:flutter/scheduler.dart';

class ResponseWatch {
  ResponseWatch({
    this.ambientWindow = const Duration(milliseconds: 300),
    this.ambientFrames = 5,
  });

  final Duration ambientWindow;
  final int ambientFrames;
  final List<int> _stamps = [];
  int frames = 0;
  bool _active = false;
  bool _registered = false;

  void install() {
    _active = true;
    if (_registered) return;
    _registered = true;
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      if (!_active) return;
      frames += 1;
      final now = DateTime.now().millisecondsSinceEpoch;
      _stamps.add(now);
      _stamps.removeWhere((t) => now - t > 2000);
    });
  }

  void uninstall() => _active = false;

  bool ambient() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final window = ambientWindow.inMilliseconds;
    return _stamps.where((t) => now - t <= window).length >= ambientFrames;
  }

  bool changedSince(int framesBefore) =>
      frames != framesBefore || SchedulerBinding.instance.hasScheduledFrame;
}
