# Changelog

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
