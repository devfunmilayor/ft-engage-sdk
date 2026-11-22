# Privacy and data collected

## What the SDK sends

Every request carries the public key in an `Authorization` header and a JSON body.

**Device registration** (`/v1/register`): install id (random, created on first run), platform (`ios`, `android` or `web`), SDK version, app version if you pass it, timezone name, locale, push permission status, and the push token only when push is granted.

**Events** (`/v1/events`): event id, event name, install id, the user id if you called `identify`, the screen if you pass one, the time, and the properties you pass.

## What it does not do

- No advertising id, no device fingerprinting, no contacts, no location, no clipboard.
- No automatic collection of personal data. User ids and properties are only what your app passes in.
- Money data cannot be sent: financial-looking property keys are rejected.

The server necessarily sees the network address of each request. The SDK does not put it in the payload.

## Consent

With `requireConsent: true` nothing is collected until `setConsent(ConsentState.granted)`. Denying consent clears the queue.

## Forgetting a user

`forget()` clears the stored install id, user id, consent, pending registration and the event queue, then creates a new random install id. It does not delete data already stored on the server. Use your FT.Engage project's deletion process for that.

## Local storage

State is stored with shared preferences under keys starting `ft_engage.`: install id, user id, consent, queue, and a pending registration.
