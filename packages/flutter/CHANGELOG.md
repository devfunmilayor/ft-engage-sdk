# Changelog

## 0.2.0

- Storage is now Hive CE with AES-256 encryption. The key is kept in the platform keychain or keystore. `shared_preferences` is no longer used.
- `FtEngage.init` takes `storage:` instead of `store:`.
- Data saved by 0.1.0 in shared preferences is not migrated.

## 0.1.0

- Identity, offline queue with persistence behind `KeyValueStore`, batching (at most 50), retry with capped exponential backoff, consent state, `Transport` and `Clock` interfaces.
- Client-side rejection of financial-looking property keys.
- `forget()` clears local identity and the queue.
