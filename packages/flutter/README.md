# ft_engage_flutter

Flutter plugin for FT.Engage. It stores state in encrypted Hive CE boxes, tracks app lifecycle events, registers the device and reports push permission state.

```dart
final engage = await FtEngage.init(
  publicKey: 'pk_live_...',
  endpoint: Uri.parse('https://your-api.example.com'),
);
await engage.identify('user_1001');
await engage.track('signup.completed', props: {'plan': 'free'});
```

Built on `ft_engage_core`. See the repository docs for the API reference and privacy notes.
