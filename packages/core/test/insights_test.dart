import 'dart:math';

import 'package:ft_engage_core/ft_engage_core.dart';
import 'package:test/test.dart';

import 'support.dart';

class Logged {
  Logged(this.name, this.props, this.screen, this.at);

  final String name;
  final Map<String, Object?> props;
  final String? screen;
  final DateTime? at;
}

class Rig {
  Rig({
    InsightsConfig config = const InsightsConfig(),
    int seed = 1,
    EngageStorage? storage,
  }) : clock = FakeClock(epoch) {
    recorder = InsightsRecorder(
      config: config,
      clock: clock,
      random: Random(seed),
      storage: storage,
      track: (name, {props = const {}, screen, at}) async {
        events.add(Logged(name, props, screen, at));
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
      track: (name, {props = const {}, screen, at}) async =>
          throw StateError('boom'),
    );
    recorder.screenViewed('home');
    recorder.tap(
      const TapSample(x: 1, y: 1, viewportWidth: 10, viewportHeight: 10),
    );
    await Future<void>.delayed(Duration.zero);
  });

  test('ids and query strings in screen names collapse into one screen', () {
    expect(normalizeScreenName('/order/8841'), '/order/:id');
    expect(normalizeScreenName('/order/8841/'), '/order/:id');
    expect(
      normalizeScreenName(
        '/user/3f2b8c1e-7a44-4b0e-9d52-1c0f5a6b7d88/settings',
      ),
      '/user/:id/settings',
    );
    expect(normalizeScreenName('/doc/5f1d7f3a9b2c4d6e8a0b1c2d'), '/doc/:id');
    expect(normalizeScreenName('/share/Ab3dE5gH7jK9mN1pQ'), '/share/:id');
    expect(normalizeScreenName('/search?q=shoes&page=2'), '/search');
    expect(normalizeScreenName('/profile#bio'), '/profile');
    expect(normalizeScreenName('/'), '/');
    expect(normalizeScreenName('Checkout'), 'Checkout');
    expect(normalizeScreenName('/settings/privacy'), '/settings/privacy');
    expect(normalizeScreenName('/onboarding/step-2'), '/onboarding/step-2');
    expect(
      normalizeScreenName('/a/averyveryverylongwordwithnodigits'),
      '/a/averyveryverylongwordwithnodigits',
    );
  });

  test(
    'screens that differ only by an id are one screen, and the setting can be changed',
    () {
      final rig = Rig();
      rig.recorder.screenViewed('/order/1');
      rig.recorder.screenViewed('/order/2');
      rig.recorder.screenViewed('/order/3');
      rig.recorder.screenViewed('/help');
      final views = rig.named('screen.viewed');
      expect(views.map((v) => v.screen).toList(), ['/order/:id', '/help']);
      expect(views[1].props['from'], '/order/:id');

      final raw = Rig(config: const InsightsConfig(normalizeScreens: false));
      raw.recorder.screenViewed('/order/1');
      raw.recorder.screenViewed('/order/2');
      expect(raw.named('screen.viewed'), hasLength(2));

      final custom = Rig(
        config: InsightsConfig(screenName: (n) => n.toUpperCase()),
      );
      custom.recorder.screenViewed('/a/1');
      expect(custom.named('screen.viewed').single.screen, '/A/1');
    },
  );

  test(
    'taps on a scrolling screen say how far down the page the person was',
    () {
      final rig = Rig();
      rig.recorder.screenViewed('home');
      rig.tapAt(10, 10);
      expect(rig.named('ui.tap').last.props.containsKey('ch'), false);
      rig.recorder.metrics(offset: 0, contentHeight: 3200);
      rig.tapAt(10, 10);
      rig.recorder.scroll(0.5, offset: 1200.4, contentHeight: 3200);
      rig.tapAt(10, 10);
      final taps = rig.named('ui.tap');
      expect(taps[1].props['so'], 0);
      expect(taps[1].props['ch'], 3200);
      expect(taps[2].props['so'], 1200);
      rig.recorder.screenViewed('about');
      rig.tapAt(10, 10);
      expect(rig.named('ui.tap').last.props.containsKey('ch'), false);
      rig.recorder.metrics(offset: 0, contentHeight: double.nan);
      rig.recorder.metrics(offset: 0, contentHeight: -4);
      rig.tapAt(10, 10);
      expect(rig.named('ui.tap').last.props.containsKey('ch'), false);
    },
  );

  test(
    'scroll depth survives the app being killed and is sent at its original time on the next start',
    () async {
      final storage = MemoryStore();
      final first = Rig(storage: storage);
      first.recorder.screenViewed('home');
      first.recorder.scroll(0.05);
      first.recorder.scroll(0.35);
      first.recorder.scroll(0.38);
      first.recorder.scroll(0.62);
      await Future<void>.delayed(Duration.zero);
      expect(
        await storage.read('ft_engage.insights.pending'),
        contains('"depth":62'),
      );
      expect(first.named('ui.scroll_depth'), isEmpty);

      final second = Rig(storage: storage);
      await second.recorder.recover();
      await Future<void>.delayed(Duration.zero);
      final recovered = second.named('ui.scroll_depth');
      expect(recovered, hasLength(1));
      expect(recovered.single.screen, 'home');
      expect(recovered.single.props['depth'], 62);
      expect(recovered.single.props['recovered'], true);
      expect(recovered.single.at, epoch);
      expect(await storage.read('ft_engage.insights.pending'), isNull);
      await second.recorder.recover();
      await Future<void>.delayed(Duration.zero);
      expect(second.named('ui.scroll_depth'), hasLength(1));
    },
  );

  test(
    'a clean exit from the screen leaves nothing to recover and bad leftovers are ignored',
    () async {
      final storage = MemoryStore();
      final rig = Rig(storage: storage);
      rig.recorder.screenViewed('home');
      rig.recorder.scroll(0.5);
      await Future<void>.delayed(Duration.zero);
      rig.recorder.screenViewed('signup');
      await Future<void>.delayed(Duration.zero);
      expect(await storage.read('ft_engage.insights.pending'), isNull);
      expect(rig.named('ui.scroll_depth'), hasLength(1));

      for (final junk in [
        'not json',
        '{"screen":1}',
        '{"screen":"a","depth":500,"at":"2026-01-01T00:00:00Z"}',
        '{"screen":"a","depth":5,"at":"nope"}',
      ]) {
        await storage.write('ft_engage.insights.pending', junk);
        final fresh = Rig(storage: storage);
        await fresh.recorder.recover();
        await Future<void>.delayed(Duration.zero);
        expect(fresh.events, isEmpty, reason: junk);
        expect(await storage.read('ft_engage.insights.pending'), isNull);
      }
    },
  );
}
