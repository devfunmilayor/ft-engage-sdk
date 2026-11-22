# API reference

## FtEngage (ft_engage_flutter)

| Member | Purpose |
|---|---|
| `FtEngage.init({publicKey, endpoint, requireConsent, appVersion, pushSource, transport, storage, flushInterval, observeLifecycle})` | Create the client. `publicKey` and `endpoint` are required, and there is no default endpoint. |
| `identify(userId)` | Attach a user id (1 to 128 characters) to later events. |
| `track(name, {props, screen})` | Queue an event. Throws `InvalidEventException` for a bad name or property. |
| `setConsent(state)` | `granted`, `denied` or `unknown`. |
| `flush()` | Send queued events now. Returns a `FlushResult`. |
| `forget()` | Clear identity, queue, consent and registration, and issue a new install id. |
| `dispose()` | Stop lifecycle observation and timers. |
| `client` | The underlying `EngageClient`. |

Automatic events: `app.opened` on init, `app.foregrounded` on resume, `app.backgrounded` on pause.

## EngageClient (ft_engage_core)

Same methods, plus `register(RegisterInfo)`, `installId`, `userId`, `consent`, `pendingCount` and `flush({force})`. Inject `Transport`, `EngageStorage`, `Clock` and `IdGenerator` for tests. `EngageStorage` combines a small key-value store with an ordered event queue, and `MemoryStore` is the in-memory version.

## Delivery

- Events are stored on the device and sent in batches of at most 50.
- Network errors, 429 and 5xx keep the events and retry with backoff: 5s, 10s, 20s and so on, capped at 5 minutes.
- A 400 or 422 response drops that batch, because retrying cannot fix it.
- Each event has a unique id, so a repeat delivery is counted once by the server.
- The queue holds at most 1000 events and drops the oldest beyond that.

## Errors

- `EngageConfigException`: bad key, secret key, or non-https endpoint (http is allowed only for localhost).
- `InvalidEventException`: invalid event name or property, including financial-looking keys.
