# Changelog

## 0.13.0

- In-app messages: `EngageInApp` draws cards and banners from the console when their trigger event happens, and reports `inapp.shown`, `inapp.clicked` and `inapp.dismissed`. `FtEngage.init` takes `inAppMessages` (on by default).
- Sessions: `session.started` and `session.ended` are sent automatically. `FtEngage.init` takes `sessionTimeout` (30 minutes by default, `null` turns sessions off).
- With `ReplayConfig(captureFieldText: true)` a replay snapshot carries the text of text boxes that pass the safety rules, never password, PIN, code, card, account, balance or amount boxes.
- Leaving a text box sends a `form.field` event with the box name, filled or empty, a length bucket and time spent, never the value (`InsightsConfig(forms: false)` turns it off).
- Taps carry a `label` and `role` read from the control's accessibility label, tooltip or button text, never from list rows, text boxes or `EngageSensitive` areas, and dropped when it looks like money, contact details or a name.
- `FtEngage.init` takes `timezone`, an IANA name such as `Africa/Lagos`. The device registration now sends an IANA time zone instead of an abbreviation such as `WAT`, which the server could not use to time messages to the local hour.
- Requires `ft_engage_core` 0.13.0.

## 0.12.0

- `FtEngage.identify` takes `userHashExpiresAt` (requires `ft_engage_core` 0.12.0).

## 0.11.0

- `FtEngage.reportAttribution` and `FtEngage.trackLinkOpened` (require `ft_engage_core` 0.11.0).

## 0.10.0

- `FtEngage.logout()` unlinks the install on the server (requires `ft_engage_core` 0.10.0).

## 0.9.0

- `FtEngage.init(appId: ...)` names the app (a bundle id or package name is a good choice). Requires `ft_engage_core` 0.9.0.

## 0.8.0

- `PushChanges` and `PushPermission` are optional extras for a `PushSource`. A source that implements `PushChanges` makes the plugin register again when the token or permission changes, and `FtEngage.requestPushPermission()` asks through a source that implements `PushPermission`.

## 0.7.0

- Session replay, off unless you pass `replay: ReplayConfig()` to `FtEngage.init`. It records a wireframe of each screen (boxes, kinds and colours, no text, no images) with the taps and scrolling on it. `EngageSensitive` areas are drawn as masked blocks and their taps are left out. Requires `ft_engage_core` 0.7.0.

## 0.6.0

- Dead taps are confirmed before they are reported: after a tap that looks dead the plugin waits 400 ms and drops the flag if the app navigated, scrolled, moved focus or drew a new frame, unless the screen was already animating continuously. Requires `ft_engage_core` 0.6.0.
- Scroll metrics are read as soon as a page lays out, so even taps before the first scroll know the page height.

## 0.5.0

- Opt-in behaviour insights: pass `insights: InsightsConfig()` to `FtEngage.init`, wrap the app in `EngageInsights`, and add `engage.navigatorObserver` to your navigator. Captures taps (with dead taps), rage taps, screens and scroll depth. `EngageTarget` names a part of the screen and `EngageSensitive` excludes one. Requires `ft_engage_core` 0.5.0.

## 0.4.0

- `identify` accepts `userHash`. Requires `ft_engage_core` 0.4.0.

## 0.3.0

- `identify` accepts email, phone, traits and marketing consent, and there is a new `logout()`. Requires `ft_engage_core` 0.3.0.

## 0.2.0

- Storage is now Hive CE with AES-256 encryption. The key is kept in the platform keychain or keystore. `shared_preferences` is no longer used.
- `FtEngage.init` takes `storage:` instead of `store:`.
- Data saved by 0.1.0 in shared preferences is not migrated.

## 0.1.0

- Identity, offline queue with persistence behind `KeyValueStore`, batching (at most 50), retry with capped exponential backoff, consent state, `Transport` and `Clock` interfaces.
- Client-side rejection of financial-looking property keys.
- `forget()` clears local identity and the queue.
