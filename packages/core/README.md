# ft_engage_core

Pure Dart core of the FT.Engage SDK. It has no Flutter dependency, so it also runs in plain Dart programs and tests.

```dart
final client = await EngageClient.create(
  config: EngageConfig(
    publicKey: 'pk_live_...',
    endpoint: Uri.parse('https://your-api.example.com'),
  ),
  transport: HttpTransport(),
  store: myKeyValueStore,
);
await client.identify('user_1001');
await client.track('signup.completed', props: {'plan': 'free'});
await client.flush();
```

Most apps should use `ft_engage_flutter`, which supplies storage, lifecycle events and device registration. See the repository docs for the API reference and privacy notes.
