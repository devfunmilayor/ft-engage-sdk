# API reference

## FtEngage (ft_engage_flutter)

| Member | Purpose |
|---|---|
| `FtEngage.init({publicKey, endpoint, requireConsent, appVersion, appId, timezone, sessionTimeout, pushSource, transport, storage, flushInterval, observeLifecycle, insights, replay})` | Create the client. `publicKey` and `endpoint` are required, and there is no default endpoint. `timezone` is the device's IANA time zone, such as `Africa/Lagos`, for example from the `flutter_timezone` package. Without it the SDK sends `UTC` or an `Etc/GMT` zone worked out from the device's offset, and nothing for offsets that are not whole hours. Campaigns that deliver at a local hour use it. |
| `identify(userId, {userHash, email, phone, traits, marketingConsent})` | Link this install to a person and tag later events with the user id. Sends `/v1/identify` after registration. Throws `InvalidIdentityException` for a bad value. See below. |
| `logout()` | Stop tagging events with the user id, drop any identity still waiting to be sent, and ask the server to unlink this install from the person (`POST /v1/logout`). If the device is offline the request is kept and retried before the next identify. Keeps the install id and consent. |
| `track(name, {props, screen})` | Queue an event. Throws `InvalidEventException` for a bad name or property. |
| `setConsent(state)` | `granted`, `denied` or `unknown`. |
| `flush()` | Send queued events now. Returns a `FlushResult`. |
| `screen(name)` | Record that a screen appeared, for apps without named routes. Does nothing unless insights are on. |
| `navigatorObserver` | Add to `navigatorObservers` so named routes become screens. |
| `forget()` | Clear identity, queue, consent and registration, and issue a new install id. |
| `dispose()` | Stop lifecycle observation and timers. |
| `client` | The underlying `EngageClient`. |

Automatic events: `app.opened` on init, `app.foregrounded` on resume, `app.backgrounded` on pause.

Sessions: a session starts at launch, or on resume after more than `sessionTimeout` (30 minutes by default) without the app in use, and is sent as `session.started` with `session_number` and `first`. When the next session starts, the previous one is sent as `session.ended` with `session_number` and `duration_seconds`, timed at its last activity. Pass `sessionTimeout: null` to turn sessions off. `engage.sessions` is the `SessionTracker`, or `null` when off.

## EngageClient (ft_engage_core)

Same methods, plus `register(RegisterInfo)`, `installId`, `userId`, `consent`, `pendingCount` and `flush({force})`. Inject `Transport`, `EngageStorage`, `Clock` and `IdGenerator` for tests. `EngageStorage` combines a small key-value store with an ordered event queue, and `MemoryStore` is the in-memory version.

## Identity

- `userHash`: proof from your own server that this app session really belongs to `userId`. See "Signed identity" below.
- `userId`: 1 to 128 characters from letters, digits and `_ . : @ + -`.
- `email` must look like an address. `phone` must be international format such as `+2348012345678`.
- `traits` are flat: text up to 200 characters, numbers, booleans or `null` (which removes the trait). Names are lowercase snake_case, at most 30 per call. Names that look like money or secrets (`password`, `token`, `card`, `balance`, `amount` and similar) are rejected.
- `marketingConsent` records the person's choice per channel (`email`, `whatsapp`, `sms`). It is separate from `setConsent`, which controls whether the SDK collects data at all. Only set it from a choice the person actually made. A refusal recorded by your team in the console cannot be reversed by the app.
- Several calls for the same user before delivery are merged into one request. A different user replaces anything still waiting.
- With `requireConsent: true` and no `granted` consent, `identify` sends and stores nothing but the user id. Call it again after consent.
- Delivery follows the same rules as events: registration first, then identity, then events. 400 drops the request. 404 (the server has not seen the install yet), 429, 5xx and network errors keep it and retry with backoff.
- Unlinking needs a server that has `POST /v1/logout`. An older server answers `404` and the SDK treats that as done, so on it the install stays linked to the previous person until someone else identifies.

## Signed identity

The public key is inside every copy of your app, so on its own it cannot prove who someone is. When a project requires signed identity, FT.Engage rejects an identify call whose `userHash` is missing or wrong (`401 identity_unverified`). The SDK treats that as a rejected request and drops it, so a wrong hash never retries.

1. In the console, open People, then Identity security, and copy your project's identity secret. Keep it on your server only. Never put it in the app.
2. When someone signs in, your server computes `HMAC-SHA256(secret, userId)` as lowercase hex and returns it to the app together with the sign-in result.
3. The app passes it along: `engage.identify(userId, userHash: hashFromServer)`.

```js
import { createHmac } from 'node:crypto';
const userHash = createHmac('sha256', process.env.ENGAGE_IDENTITY_SECRET).update(userId).digest('hex');
```

This plain hash covers the user id only and never stops working until you rotate the secret, so keep it as private as a session token, send it over TLS only, and generate it only after your own sign-in succeeded. Rotating the secret in the console invalidates every hash at once.

### Hashes that expire

A hash can carry a deadline, so a copy that leaks stops working on its own. Your server picks the deadline, signs it into the hash, and returns both to the app:

```js
import { createHmac } from 'node:crypto';
const expiresAt = Math.floor(Date.now() / 1000) + 24 * 3600; // seconds since 1970
const userHash = createHmac('sha256', process.env.ENGAGE_IDENTITY_SECRET)
  .update(`${userId}\n${expiresAt}`) // user id, a newline, then the deadline
  .digest('hex');
```

```dart
await engage.identify(
  userId,
  userHash: hashFromServer,
  userHashExpiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAtSeconds * 1000, isUtc: true),
);
```

FT.Engage checks the signature over the user id and the deadline together, then refuses an expired hash (`401 identity_expired`) and a deadline more than 30 days away. The SDK drops a rejected identify, so an expired hash is not retried. Pick a deadline longer than the longest time the app may be offline before it can send, and call `identify` again with a fresh hash whenever your own session is refreshed. A project can be set to refuse hashes without a deadline once all your apps send one (the console shows this under identity security). `userHashExpiresAt` needs `ft_engage_core` 0.12.0 or later, and a server that understands it; older apps keep working with the plain hash until you turn that switch on.

Calls made with a secret key from your server need no hash.

## Delivery

- Events are stored on the device and sent in batches of at most 50.
- Network errors, 429 and 5xx keep the events and retry with backoff: 5s, 10s, 20s and so on, capped at 5 minutes.
- A 400 or 422 response drops that batch, because retrying cannot fix it.
- Each event has a unique id, so a repeat delivery is counted once by the server.
- The queue holds at most 1000 events and drops the oldest beyond that.

## Errors

- `EngageConfigException`: bad key, secret key, or non-https endpoint (http is allowed only for localhost).
- `InvalidEventException`: invalid event name or property, including financial-looking keys.

## Attribution

Tracking links made in the FT.Engage console send people to the store and, on Google Play, put a click id in the install referrer. After install, the app reads the referrer and reports it, and the server attributes the install to the link.

| Call | What it does |
|---|---|
| `reportAttribution({referrer, appleToken})` | Reports where the install came from. Pass the Google Play install referrer string on Android, or the Apple Search Ads token on iOS (Apple's AdServices `AAAttribution.attributionToken()`). Returns an `AttributionResult` (`attributed`, `source`, `medium`, `campaign`, `method`, `deepLink`, `retry`) or `null` if nothing was sent (no consent, nothing to report, or the network failed, so call it again later). `retry: true` means the server or Apple has no answer yet. An attributed answer is remembered on the device and later calls return it without a request. |
| `trackLinkOpened(Uri)` | Tracks a `link.opened` event with the host and any `utm_source`, `utm_medium` and `utm_campaign` of a link that opened the app. Nothing else from the link is sent. |

Reading the referrer or the Apple token needs native code that this SDK does not include yet: use Google's Install Referrer API on Android and Apple's AdServices framework on iOS (through a plugin you already use or a small platform channel) and pass the result in. Attribution is exact for Google Play links and Apple Search Ads. A link opened on an iPhone and installed from the App Store cannot be tied back to the click.
