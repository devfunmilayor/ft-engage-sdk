import 'dart:math';

import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

class Logged {
  Logged(this.name, this.props, this.screen);

  final String name;
  final Map<String, Object?> props;
  final String? screen;
}

class Rig {
  Rig({InsightsConfig config = const InsightsConfig(), int seed = 1})
    : clock = FakeClock(epoch) {
    recorder = InsightsRecorder(
      config: config,
      clock: clock,
      random: Random(seed),
      track: (name, {props = const {}, screen}) async {
        events.add(Logged(name, props, screen));
      },
    );
  }

  final FakeClock clock;
  final List<Logged> events = [];
  late final InsightsRecorder recorder;

  List<Logged> named(String name) =>
      events.where((e) => e.name == name).toList();

  void tapAt(
    double x,
    double y, {
    bool dead = false,
    String? target,
    double w = 400,
    double h = 800,
  }) => recorder.tap(
    TapSample(
      x: x,
      y: y,
      viewportWidth: w,
      viewportHeight: h,
      dead: dead,
      target: target,
    ),
  );
}

void main() {
  test(
    'a screen view carries the session and where the person came from, and repeats are ignored',
    () {
      final rig = Rig();
      rig.recorder.screenViewed('home');
      rig.recorder.screenViewed('home');
      rig.recorder.screenViewed('signup');
      rig.recorder.screenViewed('  ');
      rig.recorder.screenViewed('x' * 129);
      final views = rig.named('screen.viewed');
      expect(views, hasLength(2));
      expect(views[0].screen, 'home');
      expect(views[0].props.containsKey('from'), false);
      expect(views[1].props['from'], 'home');
      expect(views[1].props['sid'], views[0].props['sid']);
      expect(views[0].props['sid'], matches(RegExp(r'^s[0-9a-f]{8}$')));
    },
  );

  test(
    'a tap is normalised to the screen, rounded, clamped and never carries text',
    () {
      final rig = Rig();
      rig.recorder.screenViewed('home');
      rig.tapAt(100, 200);
      rig.tapAt(-5, 900, dead: true, target: 'buy_button');
      final taps = rig.named('ui.tap');
      expect(taps[0].props, {
        'x': 0.25,
        'y': 0.25,
        'vw': 400,
        'vh': 800,
        'sid': rig.recorder.sessionId,
      });
      expect(taps[0].screen, 'home');
      expect(taps[1].props['x'], 0.0);
      expect(taps[1].props['y'], 1.0);
      expect(taps[1].props['dead'], true);
      expect(taps[1].props['target'], 'buy_button');
      rig.tapAt(133.3333, 1);
      expect(rig.named('ui.tap').last.props['x'], 0.333);
    },
  );

  test(
    'taps need a screen and a real viewport and stop at the per-screen limit',
    () {
      final rig = Rig(
        config: const InsightsConfig(maxTapsPerScreen: 3, rageTaps: 99),
      );
      rig.tapAt(1, 1);
      expect(rig.events, isEmpty);
      rig.recorder.screenViewed('home');
      rig.recorder.tap(
        const TapSample(x: 1, y: 1, viewportWidth: 0, viewportHeight: 0),
      );
      for (var i = 0; i < 10; i++) {
        rig.tapAt(10.0 * i, 10);
      }
      expect(rig.named('ui.tap'), hasLength(3));
      rig.recorder.screenViewed('signup');
      rig.tapAt(5, 5);
      expect(rig.named('ui.tap'), hasLength(4));
    },
  );

  test(
    'three quick taps in one place are one rage tap, and a new burst after a pause is another',
    () {
      final rig = Rig();
      rig.recorder.screenViewed('home');
      for (var i = 0; i < 5; i++) {
        rig.tapAt(100, 100);
        rig.clock.advance(const Duration(milliseconds: 150));
      }
      final rage = rig.named('ui.rage_tap');
      expect(rage, hasLength(1));
      expect(rage.single.props['taps'], 3);
      expect(rage.single.props['x'], 0.25);
      expect(rig.named('ui.tap'), hasLength(5));
      rig.clock.advance(const Duration(seconds: 3));
      for (var i = 0; i < 3; i++) {
        rig.tapAt(300, 500);
        rig.clock.advance(const Duration(milliseconds: 100));
      }
      expect(rig.named('ui.rage_tap'), hasLength(2));
    },
  );

  test('taps far apart or too slow are not rage', () {
    final rig = Rig();
    rig.recorder.screenViewed('home');
    for (final x in [10.0, 150.0, 300.0, 390.0]) {
      rig.tapAt(x, 100);
      rig.clock.advance(const Duration(milliseconds: 100));
    }
    for (var i = 0; i < 4; i++) {
      rig.tapAt(100, 400);
      rig.clock.advance(const Duration(milliseconds: 600));
    }
    expect(rig.named('ui.rage_tap'), isEmpty);
  });

  test(
    'the deepest scroll is reported once, when the person leaves the screen or the app goes to the background',
    () {
      final rig = Rig();
      rig.recorder.screenViewed('home');
      rig.recorder.scroll(0.2);
      rig.recorder.scroll(0.756);
      rig.recorder.scroll(0.4);
      rig.recorder.scroll(double.nan);
      expect(rig.named('ui.scroll_depth'), isEmpty);
      rig.recorder.screenViewed('signup');
      var depth = rig.named('ui.scroll_depth');
      expect(depth, hasLength(1));
      expect(depth.single.screen, 'home');
      expect(depth.single.props['depth'], 76);
      rig.recorder.scroll(5);
      rig.recorder.leaveScreen();
      rig.recorder.leaveScreen();
      depth = rig.named('ui.scroll_depth');
      expect(depth, hasLength(2));
      expect(depth.last.screen, 'signup');
      expect(depth.last.props['depth'], 100);
      rig.recorder.screenViewed('about');
      expect(rig.named('ui.scroll_depth'), hasLength(2));
    },
  );

  test('a long pause starts a new session', () {
    final rig = Rig();
    rig.recorder.screenViewed('home');
    final first = rig.recorder.sessionId;
    rig.clock.advance(const Duration(minutes: 10));
    rig.tapAt(1, 1);
    expect(rig.recorder.sessionId, first);
    rig.clock.advance(const Duration(minutes: 45));
    rig.tapAt(1, 1);
    expect(rig.recorder.sessionId, isNot(first));
    expect(rig.named('ui.tap').last.props['sid'], rig.recorder.sessionId);
  });

  test(
    'sampling decides per session and a sampled-out session records nothing',
    () {
      final none = Rig(config: const InsightsConfig(sampleRate: 0));
      none.recorder.screenViewed('home');
      none.tapAt(1, 1);
      none.recorder.scroll(1);
      none.recorder.screenViewed('signup');
      expect(none.events, isEmpty);
      var kept = 0;
      for (var seed = 0; seed < 200; seed++) {
        final rig = Rig(
          config: const InsightsConfig(sampleRate: 0.25),
          seed: seed,
        );
        rig.recorder.screenViewed('home');
        rig.tapAt(1, 1);
        rig.tapAt(2, 2);
        final taps = rig.named('ui.tap').length;
        expect(taps == 0 || taps == 2, true);
        if (taps > 0) kept += 1;
      }
      expect(kept, inInclusiveRange(25, 75));
    },
  );

  test('each kind of capture can be turned off', () {
    final rig = Rig(
      config: const InsightsConfig(screens: false, taps: false, scroll: false),
    );
    rig.recorder.screenViewed('home');
    rig.tapAt(1, 1);
    rig.recorder.scroll(1);
    rig.recorder.screenViewed('signup');
    expect(rig.events, isEmpty);
    expect(rig.recorder.screen, 'signup');
  });

  test('a failing track never breaks the app', () async {
    final recorder = InsightsRecorder(
      config: const InsightsConfig(),
      track: (name, {props = const {}, screen}) async =>
          throw StateError('boom'),
    );
    recorder.screenViewed('home');
    recorder.tap(
      const TapSample(x: 1, y: 1, viewportWidth: 10, viewportHeight: 10),
    );
    await Future<void>.delayed(Duration.zero);
  });
}
