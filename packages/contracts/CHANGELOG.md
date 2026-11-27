# Changelog

## 0.8.0

- A replay `f` node can carry the text of the box as a sixth item (1 to 80 characters), only for field nodes.
- Event property names that look like secrets are refused by the `event` schema.

## 0.7.0

- `identify` accepts `userHashExpiresAt` (whole seconds since 1970, 1 to 4102444800), allowed only together with `userHash`.

## 0.6.0

- Added the `attribution_install` schema: the body of `POST /v1/attribution/install` (an install id plus a referrer or an Apple token).

## 0.5.0

- Added the `unlink` schema: the body of `POST /v1/logout`, just an install id.

## 0.4.0

- Added the `replay` schema: a chunk of a wireframe session recording (screens, layout snapshots made of boxes, taps, scroll positions and app state marks). Nodes are a kind and a rectangle, never text.

## 0.3.0

- `identify` accepts an optional `userHash`, a lowercase hex HMAC-SHA256 of the user id made by your server.

## 0.2.0

- Added the `identify` schema: user id, email, phone, flat traits and per-channel marketing consent.

## 0.1.0

- First release of the event, register and batch schemas.
- Property keys must be lowercase snake_case and may not name financial values (amount, fee, rate, price, balance, revenue, volume, usd, total, cost, salary).
