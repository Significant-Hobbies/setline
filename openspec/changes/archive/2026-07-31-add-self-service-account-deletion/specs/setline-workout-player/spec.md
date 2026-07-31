## MODIFIED Requirements

### Requirement: Device-local continuity

The system SHALL persist the programme-aware execution queue, detailed active
records, and detailed completed-session history on the device before any
network request. In authenticated mode it SHALL reconcile the same versioned
state with the current user's private cloud record. Confirmed account deletion
SHALL return to account choice after attempting to clear that deleted account's
bound device state.

#### Scenario: User reloads during a workout

- **WHEN** the user reloads Setline after modifying, deferring, adding, or
  completing at least one execution
- **THEN** the system restores the workout identity, authored positions,
  current queue, actual records, and any in-progress rest deadline

#### Scenario: User has a legacy sample workout in progress

- **WHEN** version 2 or version 3 device or cloud state contains a prior session
- **THEN** the system migrates its available records without changing their
  original order or inventing unavailable detail

#### Scenario: User deletes the account

- **WHEN** a signed-in user confirms deletion and the server reports success
- **THEN** Setline attempts to remove the deleted account's bound device state,
  reports any browser-cleanup failure, and returns to account choice without
  silently entering device-only mode
