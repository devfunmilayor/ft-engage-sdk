# In-app messages

Cards and banners shown inside your app when someone does something, written and published in the FT.Engage console under In-app. Nothing ships in your app binary: you publish a message and devices pick it up.

## Set up

In-app messages are on by default. Put `EngageInApp` in `MaterialApp.builder` so it sits above every screen, and route the button's link yourself:

```dart
MaterialApp(
  builder: (context, child) => EngageInApp(
    engage: engage,
    onAction: (link) => router.go(link.path),
    child: child!,
  ),
);
```

Pass `inAppMessages: false` to `FtEngage.init` to turn them off. Pass `style: InAppStyle(...)` to `EngageInApp` to match your colors.

## How a message is chosen

- The SDK fetches the live messages for this install at start and when the app returns to the foreground, at most every five minutes, and keeps them on the device. A message that was fetched once still shows offline.
- The server only sends messages whose segment includes this install.
- When your app tracks an event that matches a message's trigger (and its screen, if one is set), the message appears after its delay.
- One message is on screen at a time. The person sees a message at most `maxShows` times, with at least `minHoursBetween` hours between showings. These counts are kept on the device.

## What is reported

| Event | When |
|---|---|
| `inapp.shown` | The message appeared. |
| `inapp.clicked` | The person tapped the button. Its link goes to `onAction`. |
| `inapp.dismissed` | The person closed it, or tapped outside a card. |

Each carries `message`, the id of the message. The console counts each person once per message. Like every event, these follow `setConsent`: with `requireConsent: true` and no consent, nothing is fetched or shown.

## Notes

- The link must be `https://` or your app's scheme. The SDK hands it to you and never opens it itself.
- A custom `Transport` must also implement `ReadTransport` for messages to be fetched. The built-in `HttpTransport` does.
- `engage.inApp` is the `InAppEngine` if you want to show messages your own way: listen to `due`, and call `shown`, `clicked` or `dismissed`.
