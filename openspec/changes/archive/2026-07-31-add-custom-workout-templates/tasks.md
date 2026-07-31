## 1. State and domain

- [x] 1.1 Add bounded custom template types, validation, fresh-ID duplication,
  and immutable session-start helpers.
- [x] 1.2 Bump `StoredState` to version 5 and migrate valid version 4 state with
  an empty custom template collection.
- [x] 1.3 Preserve custom templates through local persistence, private whole-
  state sync, JSON export, import preview, and replacement.

## 2. Programme authoring

- [x] 2.1 List custom workouts beside the bundled programme with explicit edit,
  duplicate, start, and confirmed delete actions.
- [x] 2.2 Add a bounded authoring form for workout identity and ordered exercise
  steps with modality-aware targets and rest.
- [x] 2.3 Keep draft/error/success states resilient, keyboard accessible, and
  usable at 390, 768, and 1440 pixels.

## 3. Verification and documentation

- [x] 3.1 Add focused domain, state migration, transfer, and rendered-contract
  tests.
- [x] 3.2 Capture preserve-mode design evidence and complete independent
  critique/audit with zero unresolved P0/P1 findings.
- [x] 3.3 Update product, architecture/status, and changelog truth.
- [x] 3.4 Run `npm run check`, strict OpenSpec validation, raw diff checks, and
  production build without deploying or applying a D1 migration.
