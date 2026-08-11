## Why

Setline is designed around one-handed workout execution, but its only maintained client is a web application. A native iPhone client can make active workouts, timers, records, and offline recovery feel dependable in the gym while preserving Setline's exact authored-session semantics.

## What Changes

- Add a first-party SwiftUI iPhone application using Apple frameworks and no new production dependencies.
- Match the current Setline product surface: schedule, workout playback, substitutions, rest timing, records, templates, history, analytics, settings, data transfer, and account controls.
- Keep active-workout state available offline and recover interrupted sessions without reordering authored exercises.
- Reuse existing Setline API and synchronization contracts where available; retain a useful local-only path when signed out.
- Offer Sign in with Apple beside Google, with explicit linking for an already connected account and no email-based implicit account merge.
- Add native tests, privacy metadata, app metadata, icons, simulator verification, and a signed archive workflow that stops before upload.
- Keep the web application intact and do not add a unified Fleet hub.

## Capabilities

### New Capabilities

- `native-ios-client`: Native iPhone behavior, parity requirements, local-first recovery, synchronization boundaries, accessibility, and submission preparation.

### Modified Capabilities

None.

## Impact

Adds an `ios/` Swift/Xcode surface beside the existing web application and extends the existing auth service with native Apple identity-token validation. Existing workout routes and data formats remain unchanged. The iOS app uses the personal Apple development team for signing and is prepared for a separately authorized TestFlight upload.
