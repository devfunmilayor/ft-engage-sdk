# Privacy and data collected

## What the SDK sends

Every request carries the public key in an `Authorization` header and a JSON body.

**Device registration** (`/v1/register`): install id (random, created on first run), platform (`ios`, `android` or `web`), SDK version, app version if you pass it, timezone name, locale, push permission status, and the push token only when push is granted.

**Events** (`/v1/events`): event id, event name, install id, the user id if you called `identify`, the screen if you pass one, the time, and the properties you pass.

**Identity** (`/v1/identify`): only when you call `identify`. It carries the install id, the user id, and whatever email, phone, traits and marketing consent you pass. Until it is delivered, the email and phone sit in the on-device storage, which the Flutter plugin encrypts. After delivery they are removed from the device.

**Behaviour insights** (only if you turn them on, see `docs/insights.md`): screen names, tap positions as fractions of the screen, whether a tap looked dead, scroll depth and a random session id, sent as ordinary events. Never text or field contents.

**Session replay** (only if you turn it on, see `docs/replay.md`): screen names and a wireframe of each screen as rectangles with a kind and a colour, with tap positions, scroll positions and app state marks. Never text, field contents or pixels.

## What it does not do

- No advertising id, no device fingerprinting, no contacts, no location, no clipboard.
- No automatic collection of personal data. User ids and properties are only what your app passes in.
- Money data cannot be sent: financial-looking property keys are rejected.

The server necessarily sees the network address of each request. The SDK does not put it in the payload.

## Consent

With `requireConsent: true` nothing is collected until `setConsent(ConsentState.granted)`. Denying consent clears the queue.

## Forgetting a user

`forget()` clears the stored install id, user id, consent, pending registration, pending identity and the event queue, then creates a new random install id. It does not delete data already stored on the server. Use your FT.Engage project's deletion process for that.

## Local storage

The Flutter plugin stores state on the device with Hive CE, in two boxes: `ft_engage_state` (install id, user id, consent, pending registration, pending identity) and `ft_engage_queue` (events waiting to be sent).

Both boxes are encrypted with AES-256 by default. The encryption key is random, created on first run, and kept in the platform keychain (iOS) or keystore (Android) through `flutter_secure_storage`. If the key is lost, for example after restoring a device backup, the SDK starts with empty boxes instead of failing.

Pass `storage:` to `FtEngage.init` to use your own storage, or call `HiveStorage.open(encrypt: false)` to turn encryption off. Storage is removed when the app is uninstalled.
