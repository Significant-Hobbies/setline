## ADDED Requirements

### Requirement: Optional Google-authenticated account
The system SHALL offer Google sign-in with basic identity scopes while
retaining an explicit device-only mode that does not require an account.

#### Scenario: New visitor chooses Google
- **WHEN** a new visitor selects Continue with Google
- **THEN** the system starts Better Auth's Google flow using the production
  origin and exact provider callback

#### Scenario: New visitor chooses device-only mode
- **WHEN** a new visitor selects Use this device only
- **THEN** the workout player opens without creating an account or requiring a
  network request

#### Scenario: Existing local user returns
- **WHEN** Setline finds valid device-local workout state without an account
- **THEN** it restores that state immediately and offers sign-in without
  blocking the workout

### Requirement: Private authenticated state
The system SHALL store at most one versioned workout-state document per
authenticated user and SHALL scope every read and write to the resolved session
user id.

#### Scenario: Authenticated user loads state
- **WHEN** a valid session requests the private state endpoint
- **THEN** the system returns only that user's stored state or an explicit empty
  result

#### Scenario: Unauthenticated request reaches private state
- **WHEN** a request without a valid session accesses the private state endpoint
- **THEN** the system returns an unauthorized response without account or
  workout data

#### Scenario: User writes valid state
- **WHEN** an authenticated user submits a valid, current state envelope within
  the size limit
- **THEN** the system upserts only that user's row and records its modification
  time

#### Scenario: Stale state write
- **WHEN** an authenticated device submits state older than the user's current
  D1 row
- **THEN** the system rejects the overwrite and returns the newer server
  envelope for deterministic recovery

### Requirement: Offline-safe authenticated sync
The system SHALL save workout actions on the device before attempting cloud
sync and SHALL retry pending authenticated state when connectivity returns.

#### Scenario: Connection drops during a workout
- **WHEN** a signed-in user completes or skips a set while offline
- **THEN** the action remains saved locally, preserves exercise order, and is
  marked for later sync

#### Scenario: Connection returns
- **WHEN** the browser becomes online with authenticated state pending
- **THEN** the system reconciles the local and server envelopes using explicit
  modification times

### Requirement: Account status and control
The system SHALL distinguish device-only, signed-in, syncing, synced, offline,
and sync-error states and SHALL provide an explicit sign-out action.

#### Scenario: Signed-in user reviews the header
- **WHEN** an authenticated session is active
- **THEN** the header identifies the account and current sync state without
  displacing the workout's primary action

#### Scenario: User signs out
- **WHEN** the user confirms sign-out
- **THEN** the system ends the remote session, keeps the last local workout
  cache available on that device, and returns to the account-choice state

### Requirement: OAuth legal surfaces
The system SHALL publish stable privacy and terms pages describing Google
identity data, local storage, private D1 state, retention, and deletion
boundaries.

#### Scenario: Visitor opens legal links
- **WHEN** a visitor or OAuth reviewer opens the privacy or terms URL
- **THEN** the page is readable without authentication and uses the production
  Setline origin

### Requirement: Cloudflare production origin
The system SHALL run the app, auth routes, and state routes on one Cloudflare
Worker at `setline.significanthobbies.com` with an immutable Git SHA deployment
tag.

#### Scenario: Production deployment completes
- **WHEN** the reviewed main revision passes CI and the Fleet deploy guard
- **THEN** the tagged Worker serves the custom domain with its D1 binding,
  secrets, static assets, and observability enabled
