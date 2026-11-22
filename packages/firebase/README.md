# ft_engage_firebase

Firebase Cloud Messaging push source for the FT.Engage Flutter SDK.

```dart
final engage = await FtEngage.init(
  publicKey: const String.fromEnvironment('ENGAGE_KEY'),
  endpoint: Uri.parse('https://your-api.example.com'),
  pushSource: FirebasePushSource(),
);
await engage.requestPushPermission();
```

See [docs/push.md](../../docs/push.md) for what is sent, iOS notes and how to write your own source.

Apache-2.0.
