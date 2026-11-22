# Getting started

## 1. Keys and environments

Each project has a sandbox and a production environment. Sandbox uses `pk_test_` keys and production uses `pk_live_` keys. A key from the wrong environment is rejected by the server with `403 key_environment_mismatch`. Build the key in with `--dart-define` so it can differ per build.

## 2. Initialise

```dart
final engage = await FtEngage.init(
  publicKey: const String.fromEnvironment('ENGAGE_KEY'),
  endpoint: Uri.parse('https://your-api.example.com'),
  requireConsent: true,
);
```

`FtEngage.init` creates the install id, registers the device, starts lifecycle tracking and queues `app.opened`.

## 3. Consent

If your app must ask before collecting data, set `requireConsent: true`. Until you call `engage.setConsent(ConsentState.granted)` nothing is collected, queued or sent. `ConsentState.denied` clears anything already queued.

## 4. Push state

The SDK reports push permission and token through a `PushSource` you provide, for example a thin wrapper over `firebase_messaging`:

```dart
class FirebasePushSource implements PushSource {
  @override
  Future<PushState> read() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
    return PushState(
      status: granted ? 'granted' : 'denied',
      token: granted ? await FirebaseMessaging.instance.getToken() : null,
    );
  }
}
```

Pass it as `pushSource:` to `FtEngage.init`. The token is sent only when the status is `granted`.

## 5. Check it works

Run the mock server and the example app from this repository, or point the SDK at your sandbox endpoint and watch events arrive. Events are sent every 30 seconds, when 50 are waiting, and when the app goes to the background.
