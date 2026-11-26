# FT.Engage SDK

Track installs, sessions and funnel steps from a Flutter app, and register the device for push. The SDK sends events to your FT.Engage endpoint with a public key.

| Package | What it is |
|---|---|
| `packages/contracts` | JSON Schemas for the wire format (events, batches, registration) |
| `packages/core` | Pure Dart client: identity, offline queue, batching, retry, consent |
| `packages/flutter` | Flutter plugin: encrypted storage, lifecycle events, device registration, push state |
| `example` | A small app that runs against a mock server in this repo |

## Status

Version 0.11.0. Install attribution (`reportAttribution`) and link tracking (`trackLinkOpened`). Logout unlinks the install on the server. App id header for per-key app limits. Firebase push source (`ft_engage_firebase`) with token refresh and a permission request. Opt-in session replay (wireframes, never text or pixels). Opt-in behaviour insights (screens, taps, rage and dead taps, scroll depth). Signed identity (`userHash`). Works today: identify (user id, email, phone, traits and marketing consent), logout, track, register, offline queue, retry, consent, `forget()`, lifecycle events, and encrypted on-device storage (Hive CE).
Not built yet: native push token and permission reading (you supply a `PushSource`), Android install referrer, Apple Search Ads token, deep links. The packages are on pub.dev as `ft_engage_core`, `ft_engage_flutter` and `ft_engage_firebase`.

## Integrate in about ten minutes

1. Get a **public** key (`pk_test_...` for sandbox, `pk_live_...` for production) and your endpoint URL from your FT.Engage project. Never put a secret key (`sk_...`) in an app. The SDK refuses to start with one.
2. Add the package from pub.dev:

```yaml
dependencies:
  ft_engage_flutter: ^0.11.0
```

   For push through Firebase, also add `ft_engage_firebase: ^0.11.0`. To pin to a tagged release from GitHub instead, use a `git:` dependency with `url: https://github.com/devfunmilayor/ft-engage-sdk.git`, `path: packages/flutter` and `ref: v0.11.0`.

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
- [Behaviour insights](docs/insights.md)
- [Session replay](docs/replay.md)
- [Push notifications](docs/push.md)
- [API reference](docs/api.md)
- [Event naming](docs/event-naming.md)
- [Privacy and data collected](docs/privacy.md)
- [Versioning](docs/versioning.md)

## Develop

See [CONTRIBUTING.md](CONTRIBUTING.md). Licensed under Apache-2.0.
