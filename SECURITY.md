# Security

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private vulnerability reporting on this repository (Security tab, "Report a vulnerability"). Include what you found, how to reproduce it, and which version.

You can expect an acknowledgement within a few working days. Fixes are released as a patch version with a note in the changelog.

## What the SDK protects

- It only ever holds a public key (`pk_`). A public key can register devices and write events, nothing else.
- Never place a secret key (`sk_`) in an app. The SDK refuses to start with one.
- Report anything that makes the SDK send data it does not document in docs/privacy.md.
