# Versioning

The packages follow semantic versioning and are released together with one tag, `vMAJOR.MINOR.PATCH`.

- Patch: fixes with no API or wire change.
- Minor: new features and new optional fields in the wire format.
- Major: breaking API changes or a wire change that older servers cannot read.

Before 1.0.0, minor versions may include small breaking changes, and each is listed in the changelog.

The wire format in `packages/contracts` is versioned on its own and changes only by adding optional fields within a major version. Servers must ignore nothing silently: unknown fields are rejected, so new fields ship with a server release first.
