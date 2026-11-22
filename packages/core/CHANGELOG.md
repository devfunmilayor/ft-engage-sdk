# Changelog

## 0.2.0

- Storage is now `EngageStorage`: a key-value store plus an ordered event queue (`EventStorage`). Adding an event no longer rewrites the whole queue.
- Queue operations run in order, and a flush always reads the queue from storage.
- An unreadable stored event is discarded instead of blocking delivery.
- The `store:` parameter of `EngageClient.create` is now `storage:`.

## 0.1.0

- Identity, offline queue with persistence behind `KeyValueStore`, batching (at most 50), retry with capped exponential backoff, consent state, `Transport` and `Clock` interfaces.
- Client-side rejection of financial-looking property keys.
- `forget()` clears local identity and the queue.
