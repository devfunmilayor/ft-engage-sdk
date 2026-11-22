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
  for (final (path, body) in capture.posts) {
    final kind = switch (path) {
      '/v1/register' => 'register',
      '/v1/identify' => 'identify',
      _ => 'batch',
    };
    print(jsonEncode({'kind': kind, 'payload': jsonDecode(body)}));
  }
}
