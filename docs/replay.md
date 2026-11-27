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
- **Snapshots**: the layout of the screen as a list of rectangles. Each has a kind and a position and size in logical pixels: `t` text (only the size of the block), `i` image (only a box), `b` something tappable, `f` a text field (a box, and its text only when you turn that on, see below), `x` a coloured area (with its colour) and `m` a masked area. At most 250 rectangles, taken when a screen appears, shortly after a tap, and when scrolling stops, never more than once a second and at most 40 per screen visit.
- **Taps**, with their position and whether they were dead or part of a rage burst.
- **Scroll** position and page height.
- **Marks** for the app going to the background and coming back, and for a text field being tapped.

## What is never recorded

By default no text of any kind: not labels, not what someone typed, not what a field shows. No pixels: images are empty boxes, and there are no screenshots. A text field is a box and the keyboard is not recorded. Because a snapshot is built from rectangles, a replay cannot show a name, a number or a message even by accident.

## Showing what people type in safe boxes (opt in)

Set `ReplayConfig(captureFieldText: true)` and a snapshot also carries the text of a field, but only when every one of these holds:

- The box is not obscured (a password box) and does not turn off suggestions and autocorrect (the usual setup for PIN and secret boxes).
- Its keyboard is not number, phone, date, visible password or none (custom PIN pads).
- Its label, hint and helper text, and its autofill hints, do not mention a password, PIN, passcode, security or verification code, OTP, card, CVV, account, IBAN, routing or sort code, SSN, BVN, NIN, tax, balance, amount, salary, token, secret, key, passport or licence, a security answer, and similar words, and it is not a postal address, phone number or birthday.
- Its value is not a card number (13 to 19 digits that pass the card checksum). Runs of five or more digits are replaced with dots, and at most 80 characters are kept.
- It is not inside `EngageSensitive`.

The server checks the same things again and drops or masks anything that slips through, including from an older SDK. This is a deny list, so name your own sensitive boxes clearly or wrap them in `EngageSensitive`. Capturing text is a privacy choice: tell your users, and consider leaving it off in production until your legal team agrees.

## Which boxes people use (always on with insights)

With insights on, leaving a text box sends a `form.field` event with the box's name (made from its label, for example `email`), whether it was `filled` or `empty`, a length bucket (`0`, `1-4`, `5-12`, `13+`), how many milliseconds it was focused, and `masked: true` when it is a sensitive box. It never contains what was typed. Turn it off with `InsightsConfig(forms: false)`.

Wrap anything private in `EngageSensitive`. Inside it the snapshot has one masked block and nothing else, and taps inside it are left out.

The layout itself still shows which screen someone was on and roughly what state it was in (for example, an error banner is a coloured box), so replay is not anonymous, and it follows consent: with `requireConsent: true` nothing is recorded until consent is granted, withdrawing consent throws away what is waiting, and `forget()` does the same.

## Delivery

Chunks of up to 100 events or about 120 KB are sent every 10 seconds, when the app goes to the background, and when a session ends. They are held in memory only. If the network is down the newest 20 chunks wait and are retried, and anything not sent when the app is killed is lost. Nothing about replay is written to the device.

`sampleRate` decides per session. A session left out records nothing.

## Limits

At most 5000 events per session. A session is the same session as in insights (a gap of 30 minutes starts a new one).
