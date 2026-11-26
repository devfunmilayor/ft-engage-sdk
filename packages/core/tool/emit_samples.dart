import 'dart:convert';

import 'package:ft_engage_core/ft_engage_core.dart';

class Capture implements Transport {
  final List<(String, String)> posts = [];

  @override
  Future<TransportResponse> post(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    posts.add((url.path, body));
    return const TransportResponse(200, '{}');
  }
}

Future<void> main() async {
  final capture = Capture();
  final client = await EngageClient.create(
    config: EngageConfig(
      publicKey: 'pk_test_abcdefghijklmnopqrstuvwxyz012345',
      endpoint: Uri.parse('https://api.example.com'),
    ),
    transport: capture,
  );
  await client.identify('user_1');
  await client.track('app.opened');
  await client.track(
    'signup.completed',
    props: {'plan': 'free', 'step': 3, 'invited': true, 'ref': null},
    screen: 'Signup',
  );
  await client.register(
    const RegisterInfo(
      platform: 'android',
      appVersion: '1.0.0',
      timezone: 'WAT',
      locale: 'en-NG',
      pushStatus: 'granted',
      pushToken: 'fcm_token_0000000000000000',
    ),
  );
  await client.register(
    const RegisterInfo(platform: 'ios', pushStatus: 'denied'),
  );
  await client.identify(
    'user_2',
    userHash:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    email: 'ada@example.com',
    phone: '+2348012345678',
    traits: {'plan': 'free', 'age': 31, 'verified': false, 'nickname': null},
    marketingConsent: {
      MarketingChannel.email: true,
      MarketingChannel.whatsapp: false,
    },
  );
  final insights = InsightsRecorder(
    config: const InsightsConfig(),
    track: client.track,
  );
  insights.screenViewed('/order/8841');
  insights.metrics(offset: 640, contentHeight: 3200);
  for (var i = 0; i < 3; i++) {
    insights.tap(
      const TapSample(
        x: 100,
        y: 200,
        viewportWidth: 400,
        viewportHeight: 800,
        dead: true,
        target: 'buy_button',
      ),
    );
  }
  insights.scroll(0.62, offset: 1200, contentHeight: 3200);
  insights.screenViewed('signup');
  insights.leaveScreen();
  await Future<void>.delayed(Duration.zero);
  await client.flush(force: true);
  await client.reportAttribution(
    referrer: 'ftclick=3f2b8c1e-1111-4222-8333-444455556666&utm_source=meta',
  );
  await client.logout();
  final replay = ReplayBuffer(
    config: const ReplayConfig(),
    installId: () => client.installId,
    platform: 'android',
    send: (chunk) async {
      print(jsonEncode({'kind': 'replay', 'payload': chunk}));
      return ReplayDelivery.sent;
    },
  );
  replay.session('s0a1b2c3d');
  replay.screen('/home');
  replay.snapshot(
    width: 390,
    height: 844,
    scrollOffset: 0,
    nodes: [
      ['x', 0, 0, 390, 844, 4294967295],
      ['t', 20, 60, 200, 24],
      ['i', 20, 100, 350, 180],
      ['b', 20, 300, 350, 48, 4278190335],
      ['f', 20, 360, 350, 48],
      ['m', 20, 420, 350, 100],
    ],
  );
  replay.tap(195, 320);
  replay.tap(195, 320, dead: true, rage: true);
  replay.scroll(640, contentHeight: 3200);
  replay.mark('focus');
  replay.mark('bg');
  replay.mark('fg');
  await replay.flush(end: true);
  for (final (path, body) in capture.posts) {
    final kind = switch (path) {
      '/v1/register' => 'register',
      '/v1/identify' => 'identify',
      '/v1/logout' => 'unlink',
      '/v1/attribution/install' => 'attribution',
      _ => 'batch',
    };
    print(jsonEncode({'kind': kind, 'payload': jsonDecode(body)}));
  }
}
