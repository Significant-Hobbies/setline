## Context

See `proposal.md` for motivation and `specs/native-ios-client/spec.md` for the behavior contract. Setline currently has a TypeScript web client, a device-first whole-state model, and optional Google-backed synchronization. The native client must coexist with that surface, preserve exact workout order, and remain usable without network access. The owner selected Swift, simulator-first validation, personal Apple signing, and Apple-native tooling.

## Goals / Non-Goals

**Goals:**

- Build a maintainable SwiftUI iPhone app with a testable domain layer and no third-party runtime packages.
- Preserve Setline's authored-versus-recorded distinctions and make every active-workout mutation durable immediately.
- Keep local and remote state boundaries explicit enough to add or adjust server adapters without rewriting screens.
- Produce a locally signed archive and complete metadata/privacy checklist without uploading it.

**Non-Goals:**

- Replacing or embedding the web client.
- Adding coaching, AI, HealthKit, sensors, social features, or a Fleet-wide hub.
- Publishing, monetization, App Store Connect setup, or production service changes.

## Decisions

### Native Apple stack with a generated, checked-in Xcode project

The app uses SwiftUI, Observation, Foundation, URLSession, UserNotifications, UniformTypeIdentifiers, XCTest, and OSLog. A small `project.yml` keeps the project reproducible; the generated `.xcodeproj` is checked in so everyday work happens entirely in Xcode. This avoids runtime dependencies and preserves the owner's preference for Apple's frameworks. Hand-maintaining a large project file was rejected as fragile.

### Codable domain document behind an actor

The complete local product state is a versioned Codable document written atomically in Application Support by an actor. Active-session checkpoints occur after every meaningful action. This matches Setline's existing whole-state export/sync semantics and keeps offline recovery deterministic. SwiftData was considered, but a relational migration layer adds complexity without improving the current whole-state contract.

### Feature slices over screen-owned state

Domain types and operations live in `SetlineCore`; the app target owns SwiftUI composition. Screens observe one app model and call explicit domain operations. Timers store end timestamps rather than decrementing persisted counters. This keeps tests independent of the simulator and prevents views from becoming the source of truth.

### Existing service contract through native web authentication

Optional account connection uses `ASWebAuthenticationSession` and URLSession against existing Setline endpoints. Credentials are stored only in Keychain. The remote adapter exchanges versioned whole-state payloads and never performs per-set merging or silent template rewrites. No secrets or environment files are embedded.

### Apple identity is native and account linking is explicit

The iPhone app obtains an Apple identity token with AuthenticationServices and a SHA-256 nonce, then sends it directly to Better Auth for signature, issuer, audience, expiry, and nonce validation against `com.significanthobbies.setline`. A new Apple identity may create an account. An existing Google account can add Apple only while already authenticated through an explicit link action. Matching email addresses never silently merge accounts, and a hidden Apple relay address is accepted when the owner deliberately links it.

### Preserve-mode visual adaptation

The native app inherits `DESIGN.md`: chalk/paper daylight surfaces, ink structure, lime execution signals, tabular numerals, Scoreboard Split hierarchy, sparse rounding, and one dominant action. Native navigation, sheets, focus, Dynamic Type, VoiceOver, and Reduce Motion behavior take precedence where platform conventions improve operation.

### Release boundary is local archive

Bundle identifier is `com.significanthobbies.setline`; version starts at `1.0.0` build `1`; minimum deployment is iOS 17. The archive script accepts a team override but defaults to personal team `8F7LXHTJZR`, creates an archive outside source control, verifies its signature, and has no upload command.

## Risks / Trade-offs

- [Existing API assumptions can drift] → Isolate remote DTOs, add fixture contract tests, and keep offline behavior independent.
- [Whole-state sync can overwrite newer work] → Show last-sync provenance, require explicit conflict choice, and never auto-replace a dirty local document.
- [Long workouts can expose persistence races] → Serialize mutations through one actor and test relaunch recovery at each session phase.
- [Simulator cannot validate physical gym ergonomics or notifications] → Record those as device-only release checks rather than claiming completion.

## Migration Plan

1. Add the iOS project without changing web code or production services.
2. Seed bundled programme data from a versioned native resource.
3. Validate local-only parity and recovery with unit/UI tests and simulator evidence.
4. Validate optional contract fixtures without production writes.
5. Create a personal-team archive and stop before App Store Connect.

Removing `ios/` rolls back the change without affecting web users or stored server data.
