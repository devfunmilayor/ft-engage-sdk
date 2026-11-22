# Changelog

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
