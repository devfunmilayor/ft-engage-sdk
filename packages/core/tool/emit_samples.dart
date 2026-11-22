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
    email: 'ada@example.com',
    phone: '+2348012345678',
    traits: {'plan': 'free', 'age': 31, 'verified': false, 'nickname': null},
    marketingConsent: {
      MarketingChannel.email: true,
      MarketingChannel.whatsapp: false,
    },
  );
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
