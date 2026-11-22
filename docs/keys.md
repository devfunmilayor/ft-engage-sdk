# Limiting a key

A public key ships inside your app, so anyone can read it. Your project can limit what a key is allowed to do. These limits are set by an admin in the dashboard (or the management API), not in the app.

- **Allowed origins** (web). The key is only accepted from pages on the listed origins, such as `https://app.example.com` or `https://*.example.com`. A wildcard covers subdomains, not the bare domain. Browsers set the origin themselves and scripts on other sites cannot change it.
- **Allowed apps** (mobile and desktop). The key is only accepted when the request names one of the listed apps. Pass `appId` to `FtEngage.init`, for example your bundle id or package name. It is sent as the `x-engage-app` header.
- **Daily quota**. The most events a key can send in a UTC day. Requests over the limit get `429 quota_exceeded` and the SDK keeps them queued and tries again later.

`appId` is a label, not proof. Someone who copies it can send it too, and a request that is not from a browser can say any origin it likes. Use the limits to stop accidents, leaked keys being reused on other sites, and runaway loops, and use signed identity when you need to know who a person really is.
