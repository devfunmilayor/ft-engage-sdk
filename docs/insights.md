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

Name your routes. A screen is recorded under its route name, and a route with no name is ignored. Ids are cleaned for you: numbers, UUIDs, long hex strings and long mixed tokens in a route become `:id`, and a query string or `#fragment` is dropped, so `/order/8841?tab=2` is recorded as `/order/:id`. A word like `/onboarding/step-2` is kept as it is. To change the rules pass `InsightsConfig(screenName: (name) => ...)`, or `normalizeScreens: false` to keep names exactly as given. If you do not use named routes, call `engage.screen('Checkout')` yourself when a screen appears.

## What is recorded

| Event | When | Properties |
|---|---|---|
| `screen.viewed` | a screen appears | `sid` (session), `from` (previous screen) |
| `ui.tap` | a quick tap that is not a drag | `x`, `y` (0 to 1 of the screen), `vw`, `vh` (screen size), `sid`, `so` and `ch` (scroll offset and page height in pixels, only on a screen that scrolls), `dead` (only when true), `target` (only if you named it) |
| `ui.rage_tap` | 3 taps within a second near the same place, once per burst | the same, plus `taps` |
| `ui.scroll_depth` | the person leaves a screen, the app goes to the background, or the app starts again after being killed | `sid`, `depth` (0 to 100, the deepest point reached), `recovered` (only when sent after a kill) |

A session is one run of the app with no gap of 30 minutes or more. Every event also carries the screen name in its `screen` field.

## What is never recorded

No text, no field values, no widget contents, no screenshots. A tap is a position as a fraction of the screen and nothing else. Typing in a text field is not captured, only that the field was tapped. The id of the person is whatever you gave `identify`, as with any other event.

Wrap anything private in `EngageSensitive` and taps inside it are dropped before they are queued. Everything also follows the SDK's consent: with `requireConsent: true` nothing is recorded until consent is granted.

## Dead taps

A tap is a candidate for dead when nothing under the finger looks like it handles touches: no button or ink response, no text field, no gesture detector with a tap or drag handler. Before reporting it the plugin waits 400 ms and checks whether anything happened: a new route, a scroll, a change of focus, or a new frame drawn. If so, it was not dead (a custom widget that reads raw touches and changes the screen is no longer reported). If the screen was already animating continuously when the person tapped, frames prove nothing, so only navigation, scrolling and focus can clear that tap.

This is much more precise than looking at the widget alone, but it is still a judgement. A custom widget that handles a touch without changing anything visible still counts as dead, so wrap it in `EngageTarget(id: 'map', interactive: true)`. The report is delayed by the 400 ms, and a tap in the last moments before the app closes can be lost.

The window can be changed with `EngageInsights(responseWindow: ...)`.

## Naming a part of the screen

```dart
EngageTarget(id: 'promo_banner', child: Banner())
```

Taps on it carry `target: promo_banner`. Use short ids that you are happy to see in the console and never put personal data in one.

## Limits and cost

- At most 300 taps are recorded per screen visit (`maxTapsPerScreen`).
- If the app is killed or crashes while someone is scrolling, the deepest point reached so far is kept on the device and sent the next time the app starts, with its original time. It is saved when it grows by 10 points, so up to 10 points of the last stretch can be missing.
- `sampleRate: 0.25` records a quarter of sessions, chosen once per session. Counts then describe the sampled sessions only.
- Each part can be turned off with `screens`, `taps` or `scroll`.
- Everything travels as ordinary events, in the same batches as the rest.
