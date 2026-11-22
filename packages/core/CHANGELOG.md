# Changelog

## 0.5.0

- `InsightsRecorder` and `InsightsConfig`: turn screen views, taps, rage taps, scroll depth and a session id into events (`screen.viewed`, `ui.tap`, `ui.rage_tap`, `ui.scroll_depth`). Positions are fractions of the screen, never text. Pure Dart so it can be tested without a device.

## 0.4.0

- `identify` accepts `userHash`, the HMAC your server makes for the user id, for projects that require signed identity. It is validated, kept when calls merge, and dropped when a different user identifies.

## 0.3.0

- `identify` now takes optional `email`, `phone`, `traits` and `marketingConsent`, validates them, and delivers them to `/v1/identify` after registration. Waiting identity is stored, merged, retried and cleared like the registration.
- New `logout()`, and new `InvalidIdentityException`.
- Existing `identify(userId)` calls keep working, but a user id must now be 1 to 128 characters of letters, digits and `_ . : @ + -`, and the call also links the install to the person on the server.

## 0.2.0

- Storage is now `EngageStorage`: a key-value store plus an ordered event queue (`EventStorage`). Adding an event no longer rewrites the whole queue.
- Queue operations run in order, and a flush always reads the queue from storage.
- An unreadable stored event is discarded instead of blocking delivery.
- The `store:` parameter of `EngageClient.create` is now `storage:`.

## 0.1.0

- Identity, offline queue with persistence behind `KeyValueStore`, batching (at most 50), retry with capped exponential backoff, consent state, `Transport` and `Clock` interfaces.
- Client-side rejection of financial-looking property keys.
- `forget()` clears local identity and the queue.
