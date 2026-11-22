# FT.Engage SDK

Track installs, sessions and funnel steps from a Flutter app, and register the device for push. The SDK sends events to your FT.Engage endpoint with a public key.

| Package | What it is |
|---|---|
| `packages/contracts` | JSON Schemas for the wire format (events, batches, registration) |
| `packages/core` | Pure Dart client: identity, offline queue, batching, retry, consent |
| `packages/flutter` | Flutter plugin: encrypted storage, lifecycle events, device registration, push state |
| `example` | A small app that runs against a mock server in this repo |

## Status

Version 0.3.0. Works today: identify (user id, email, phone, traits and marketing consent), logout, track, register, offline queue, retry, consent, `forget()`, lifecycle events, and encrypted on-device storage (Hive CE).
Not built yet: native push token and permission reading (you supply a `PushSource`), Android install referrer, Apple Search Ads token, deep links. Nothing is published to pub.dev.

## Integrate in about ten minutes

1. Get a **public** key (`pk_test_...` for sandbox, `pk_live_...` for production) and your endpoint URL from your FT.Engage project. Never put a secret key (`sk_...`) in an app. The SDK refuses to start with one.
2. Add the package. Until it is on pub.dev, use git:

```yaml
dependencies:
  ft_engage_flutter:
    git:
      url: https://github.com/devfunmilayor/ft-engage-sdk.git
      path: packages/flutter
      ref: v0.3.0
```

3. Initialise once at startup:

```dart
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final engage = await FtEngage.init(
    publicKey: const String.fromEnvironment('ENGAGE_KEY'),
    endpoint: Uri.parse('https://your-api.example.com'),
    appVersion: '1.0.0',
  );
  runApp(MyApp(engage: engage));
}
```

4. Identify and track:

```dart
await engage.identify(
  'user_1001',
  email: 'ada@example.com',
  traits: {'plan': 'free'},
  marketingConsent: {MarketingChannel.email: true},
);
await engage.track('signup.completed', props: {'plan': 'free'}, screen: 'Signup');
```

5. Pass the key at build time: `flutter run --dart-define=ENGAGE_KEY=pk_test_...`.

Try it without a server: `dart run example/tool/mock_server.dart`, then run the example app.

## Docs

- [Getting started](docs/getting-started.md)
- [API reference](docs/api.md)
- [Event naming](docs/event-naming.md)
- [Privacy and data collected](docs/privacy.md)
- [Versioning](docs/versioning.md)

## Develop

See [CONTRIBUTING.md](CONTRIBUTING.md). Licensed under Apache-2.0.
