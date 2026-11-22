# Session replay

Replay shows what a person did in your app as a simple moving wireframe. It is off unless you turn it on, it needs the server to allow it, and it is built so that text, images and what people type are never recorded.

## Turn it on

```dart
final engage = await FtEngage.init(
  publicKey: const String.fromEnvironment('ENGAGE_KEY'),
  endpoint: Uri.parse('https://your-api.example.com'),
  replay: const ReplayConfig(sampleRate: 0.2),
);
```

Replay needs the same setup as behaviour insights (see `insights.md`): wrap your app in `EngageInsights` and add `engage.navigatorObserver`. Passing `replay` turns insights on with its default settings if you did not.

A project must also allow replay in the console (People, Insights, Replays, Settings). Until it does, the server refuses chunks, and the SDK stops recording for that session.

## What is recorded

A replay is a list of timed events:

- **Screens**: the name of each screen, cleaned the same way as insights.
- **Snapshots**: the layout of the screen as a list of rectangles. Each has a kind and a position and size in logical pixels: `t` text (only the size of the block), `i` image (only a box), `b` something tappable, `f` a text field (only a box), `x` a coloured area (with its colour) and `m` a masked area. At most 250 rectangles, taken when a screen appears, shortly after a tap, and when scrolling stops, never more than once a second and at most 40 per screen visit.
- **Taps**, with their position and whether they were dead or part of a rage burst.
- **Scroll** position and page height.
- **Marks** for the app going to the background and coming back, and for a text field being tapped.

## What is never recorded

No text of any kind: not labels, not what someone typed, not what a field shows. No pixels: images are empty boxes, and there are no screenshots. A text field is a box and the keyboard is not recorded. Because a snapshot is built from rectangles, a replay cannot show a name, a number or a message even by accident.

Wrap anything private in `EngageSensitive`. Inside it the snapshot has one masked block and nothing else, and taps inside it are left out.

The layout itself still shows which screen someone was on and roughly what state it was in (for example, an error banner is a coloured box), so replay is not anonymous, and it follows consent: with `requireConsent: true` nothing is recorded until consent is granted, withdrawing consent throws away what is waiting, and `forget()` does the same.

## Delivery

Chunks of up to 100 events or about 120 KB are sent every 10 seconds, when the app goes to the background, and when a session ends. They are held in memory only. If the network is down the newest 20 chunks wait and are retried, and anything not sent when the app is killed is lost. Nothing about replay is written to the device.

`sampleRate` decides per session. A session left out records nothing.

## Limits

At most 5000 events per session. A session is the same session as in insights (a gap of 30 minutes starts a new one).
