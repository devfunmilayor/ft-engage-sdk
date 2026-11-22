# Contributing

1. Open an issue before large changes.
2. Branch from `main`, keep changes small, and open a pull request.
3. Run the checks before you push:

```bash
npm install
npm run test:contracts
npm run verify:wire
flutter pub get
dart format --output=none --set-exit-if-changed packages example
flutter analyze --fatal-infos
(cd packages/core && dart test)
(cd packages/flutter && flutter test)
(cd example && flutter test)
```

4. The wire format lives in `packages/contracts`. A change to a schema needs valid and invalid fixtures and a changelog entry.
5. By contributing you agree your work is licensed under Apache-2.0.
