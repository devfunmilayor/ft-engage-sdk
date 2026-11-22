# API reference

## FtEngage (ft_engage_flutter)

| Member | Purpose |
|---|---|
| `FtEngage.init({publicKey, endpoint, requireConsent, appVersion, pushSource, transport, storage, flushInterval, observeLifecycle})` | Create the client. `publicKey` and `endpoint` are required, and there is no default endpoint. |
| `identify(userId, {email, phone, traits, marketingConsent})` | Link this install to a person and tag later events with the user id. Sends `/v1/identify` after registration. Throws `InvalidIdentityException` for a bad value. See below. |
| `logout()` | Stop tagging events with the user id and drop any identity still waiting to be sent. Keeps the install id and consent. |
| `track(name, {props, screen})` | Queue an event. Throws `InvalidEventException` for a bad name or property. |
| `setConsent(state)` | `granted`, `denied` or `unknown`. |
| `flush()` | Send queued events now. Returns a `FlushResult`. |
| `forget()` | Clear identity, queue, consent and registration, and issue a new install id. |
| `dispose()` | Stop lifecycle observation and timers. |
| `client` | The underlying `EngageClient`. |

Automatic events: `app.opened` on init, `app.foregrounded` on resume, `app.backgrounded` on pause.

## EngageClient (ft_engage_core)

Same methods, plus `register(RegisterInfo)`, `installId`, `userId`, `consent`, `pendingCount` and `flush({force})`. Inject `Transport`, `EngageStorage`, `Clock` and `IdGenerator` for tests. `EngageStorage` combines a small key-value store with an ordered event queue, and `MemoryStore` is the in-memory version.

## Identity

- `userId`: 1 to 128 characters from letters, digits and `_ . : @ + -`.
- `email` must look like an address. `phone` must be international format such as `+2348012345678`.
- `traits` are flat: text up to 200 characters, numbers, booleans or `null` (which removes the trait). Names are lowercase snake_case, at most 30 per call. Names that look like money or secrets (`password`, `token`, `card`, `balance`, `amount` and similar) are rejected.
- `marketingConsent` records the person's choice per channel (`email`, `whatsapp`, `sms`). It is separate from `setConsent`, which controls whether the SDK collects data at all. Only set it from a choice the person actually made. A refusal recorded by your team in the console cannot be reversed by the app.
- Several calls for the same user before delivery are merged into one request. A different user replaces anything still waiting.
- With `requireConsent: true` and no `granted` consent, `identify` sends and stores nothing but the user id. Call it again after consent.
- Delivery follows the same rules as events: registration first, then identity, then events. 400 drops the request. 404 (the server has not seen the install yet), 429, 5xx and network errors keep it and retry with backoff.
- `logout()` does not unlink the install on the server. Until another person identifies on the same install, the server still associates the device with the previous person.

## Delivery

- Events are stored on the device and sent in batches of at most 50.
- Network errors, 429 and 5xx keep the events and retry with backoff: 5s, 10s, 20s and so on, capped at 5 minutes.
- A 400 or 422 response drops that batch, because retrying cannot fix it.
- Each event has a unique id, so a repeat delivery is counted once by the server.
- The queue holds at most 1000 events and drops the oldest beyond that.

## Errors

- `EngageConfigException`: bad key, secret key, or non-https endpoint (http is allowed only for localhost).
- `InvalidEventException`: invalid event name or property, including financial-looking keys.
