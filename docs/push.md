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

## Report deliveries and opens

Start a `PushTracker` after `FtEngage.init` so the console can show how many people received and opened each push campaign, the way it does for email:

```dart
final tracker = PushTracker(track: engage.track);
await tracker.start();
```

- A notification that arrives while the app is open is sent as `push.received`.
- A notification the person taps, including the one that launched the app, is sent as `push.opened`, once per notification.
- Both carry `send`, the id FT.Engage put in the notification's data. FT.Engage counts them only for the device the notification was sent to.
- Notifications from other senders and the silent checks used to estimate uninstalls are ignored.
- Arrivals while the app is in the background or closed are not reported, because Firebase handles those in a separate isolate. A later open still counts the notification as delivered.

## What this does not do

It does not display notifications, route taps to a screen in your app, or create Android notification channels. That is your app's job with Firebase. It also cannot be tested without a device and a Firebase project, so check a real send before you rely on it.
