# Push notifications

The SDK tells FT.Engage whether a device can receive push and, when it can, which token to send to. It does this through a `PushSource`. The `ft_engage_firebase` package is a ready-made one for apps that use Firebase Cloud Messaging.

## Set up with Firebase

1. Add Firebase to your app the usual way (`firebase_core`, `flutterfire configure`, and on iOS an APNs key uploaded to Firebase).
2. Add the packages and initialise:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:ft_engage_firebase/ft_engage_firebase.dart';
import 'package:ft_engage_flutter/ft_engage_flutter.dart';

await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
final engage = await FtEngage.init(
  publicKey: const String.fromEnvironment('ENGAGE_KEY'),
  endpoint: Uri.parse('https://your-api.example.com'),
  pushSource: FirebasePushSource(),
);
```

3. Ask for permission at a moment that makes sense to the person, not at launch:

```dart
final state = await engage.requestPushPermission();
```

The SDK then registers the device with the new state and token. It never asks on its own.

## What is sent

| Situation | `pushStatus` | `pushToken` |
|---|---|---|
| Allowed (including iOS provisional) | `granted` | the FCM token, once Firebase has one |
| Refused, including "do not ask again" | `denied` | none |
| Not asked yet, or Firebase is not ready | `unknown` | none |

The token is read again when the app comes to the foreground, after `requestPushPermission`, and whenever Firebase rotates it. A rotation matters because a campaign sent to an old token fails, and a failed send is how an uninstall is guessed.

## On iOS

Firebase can take a moment to receive the APNs token after launch. Until it does, a granted device registers without a token, and the token follows by itself when Firebase refreshes. On web, pass `FirebasePushSource(vapidKey: '...')`.

## Your own source

Any class can be a source:

```dart
class MySource implements PushSource, PushChanges, PushPermission {
  Future<PushState> read() async => const PushState(status: 'granted', token: '...');
  Stream<void> get changes => myTokenRefreshes;
  Future<PushState> request() async => ...;
}
```

`PushChanges` and `PushPermission` are optional. With only `read`, the state is checked at start and on resume.

## What this does not do

It does not receive or display notifications, handle taps on them, or create Android notification channels. That is your app's job with Firebase. It also cannot be tested without a device and a Firebase project, so check a real send before you rely on it.
