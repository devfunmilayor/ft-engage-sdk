# Changelog

## 0.13.0

- Event property names that look like secrets (pin, password, passcode, secret, token, otp, cvv, cvc, card, ssn, bvn, nin, iban, account, routing, security, credential, mnemonic, seed, passport) are refused, and so is a value that is a card number. Previously only money-like names were refused.
- `FieldPolicy` and `FieldFacts`: the rules for deciding whether a text box may be read.
- `ReplayConfig.captureFieldText` (off by default) and `InsightsConfig.forms` (on by default).

## 0.12.0

- `identify` takes `userHashExpiresAt`, the deadline your server signed into the identity hash. It is sent as `userHashExpiresAt` (whole seconds since 1970) together with `userHash`, and the pair is kept together when an identify is merged with an earlier one that has not been sent yet. Giving a deadline without a hash, or a date before 1970 or after 2100, throws `InvalidIdentityException`. Nothing changes for apps that do not use it.

## 0.11.0

- `reportAttribution({referrer, appleToken})` reports the install referrer or an Apple Search Ads token to the attribution route and returns an `AttributionResult`, remembered on the device once attributed. `trackLinkOpened(Uri)` tracks a `link.opened` event with only the host and utm tags.

## 0.10.0

- `logout()` now also tells the server to unlink this install from the person (`POST /v1/logout` with the install id), so a shared device stops receiving the previous person's messages. A request that could not be sent is kept, retried, and always goes before the next identify.

## 0.9.0

- `EngageConfig.appId` is sent as the `x-engage-app` header on every request, so a project can limit a key to named apps. It is a label, not proof of identity: anyone can copy it, so pair it with an origin list for browsers and a daily quota.

## 0.7.0

- `ReplayBuffer` and `ReplayConfig`: record a session as wireframe snapshots plus taps, scrolls and app state marks, cut into chunks and sent with `EngageClient.postReplay`. Chunks that cannot be delivered are kept (the newest 20) and retried, and a server that has replay turned off stops the recording.
- `InsightsRecorder` takes an optional `InsightsListener` to follow sessions, screens, taps and scrolling.

## 0.6.0

- Screen names are cleaned by default: ids, UUIDs and long tokens in a route become `:id` and query strings are dropped, so `/order/8841?tab=2` is the screen `/order/:id`. Turn it off with `normalizeScreens: false` or supply your own `screenName`.
- Taps on a scrolling screen carry `so` (scroll offset) and `ch` (page height), so heatmaps can show the whole page.
- The deepest scroll depth is written to storage as it grows and sent on the next start if the app was killed, at its original time and marked `recovered`.
- `EngageClient.track` accepts an optional `at` time.

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
