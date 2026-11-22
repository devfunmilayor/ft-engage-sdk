# Changelog

## 0.1.0

- Identity, offline queue with persistence behind `KeyValueStore`, batching (at most 50), retry with capped exponential backoff, consent state, `Transport` and `Clock` interfaces.
- Client-side rejection of financial-looking property keys.
- `forget()` clears local identity and the queue.
