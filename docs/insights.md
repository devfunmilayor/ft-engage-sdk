# Behaviour insights

Insights show where people tap, where they get stuck and how far they scroll, so you can see problems without asking users. They are off unless you turn them on.

## Turn it on

```dart
final engage = await FtEngage.init(
  publicKey: const String.fromEnvironment('ENGAGE_KEY'),
  endpoint: Uri.parse('https://your-api.example.com'),
  insights: const InsightsConfig(),
);

MaterialApp(
  navigatorObservers: [engage.navigatorObserver],
  builder: (context, child) => EngageInsights(engage: engage, child: child!),
  routes: { '/': ..., '/signup': ... },
);
```

Name your routes. A screen is recorded under its route name, and a route with no name is ignored. Keep names stable and free of ids (`/order`, not `/order/8841`), because each name becomes a row in the console. If you do not use named routes, call `engage.screen('Checkout')` yourself when a screen appears.

## What is recorded

| Event | When | Properties |
|---|---|---|
| `screen.viewed` | a screen appears | `sid` (session), `from` (previous screen) |
| `ui.tap` | a quick tap that is not a drag | `x`, `y` (0 to 1 of the screen), `vw`, `vh` (screen size), `sid`, `dead` (only when true), `target` (only if you named it) |
| `ui.rage_tap` | 3 taps within a second near the same place, once per burst | the same, plus `taps` |
| `ui.scroll_depth` | the person leaves a screen or the app goes to the background | `sid`, `depth` (0 to 100, the deepest point reached) |

A session is one run of the app with no gap of 30 minutes or more. Every event also carries the screen name in its `screen` field.

## What is never recorded

No text, no field values, no widget contents, no screenshots. A tap is a position as a fraction of the screen and nothing else. Typing in a text field is not captured, only that the field was tapped. The id of the person is whatever you gave `identify`, as with any other event.

Wrap anything private in `EngageSensitive` and taps inside it are dropped before they are queued. Everything also follows the SDK's consent: with `requireConsent: true` nothing is recorded until consent is granted.

## Dead taps are an estimate

A tap is called dead when nothing under the finger looks like it handles touches: no button or ink response, no text field, no gesture detector with a tap or drag handler. That covers standard Flutter widgets well. A custom widget that reads raw pointer events looks dead to this check, so either wrap it in `EngageTarget(id: 'map', interactive: true)` or ignore dead taps on that screen. Treat the numbers as a pointer to look at a screen, not as proof that something is broken.

## Naming a part of the screen

```dart
EngageTarget(id: 'promo_banner', child: Banner())
```

Taps on it carry `target: promo_banner`. Use short ids that you are happy to see in the console and never put personal data in one.

## Limits and cost

- At most 300 taps are recorded per screen visit (`maxTapsPerScreen`).
- `sampleRate: 0.25` records a quarter of sessions, chosen once per session. Counts then describe the sampled sessions only.
- Each part can be turned off with `screens`, `taps` or `scroll`.
- Everything travels as ordinary events, in the same batches as the rest.
