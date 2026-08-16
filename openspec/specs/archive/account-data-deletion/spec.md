# account-data-deletion Specification

## Purpose
TBD - created by archiving change add-self-service-account-deletion. Update Purpose after archive.
## Requirements
### Requirement: Authenticated self-service account deletion

The system SHALL let a currently authenticated user delete only their own
Setline account through Better Auth's fresh-session-protected deletion
endpoint.

#### Scenario: Fresh signed-in user confirms deletion

- **WHEN** a user with a fresh authenticated session confirms account deletion
- **THEN** Setline deletes that user and returns a successful deletion result

#### Scenario: Request has no authenticated session

- **WHEN** an unauthenticated request reaches the deletion endpoint
- **THEN** Setline rejects it without deleting any user or workout data

#### Scenario: Session is not fresh enough

- **WHEN** Better Auth determines that the authenticated session is stale
- **THEN** Setline rejects deletion and keeps the account and workout state
  intact

### Requirement: Complete user-scoped cloud deletion

The system SHALL delete the user's linked OAuth account, sessions, and private
workout-state row when the owning user row is deleted.

#### Scenario: User row is deleted

- **WHEN** account deletion removes the authenticated user row
- **THEN** the existing D1 foreign-key cascades remove every linked account,
  session, and `workout_state` row for that user

### Requirement: Explicit irreversible confirmation

The system SHALL present account deletion as a secondary destructive action and
require the signed-in user to explicitly confirm the irreversible result.

#### Scenario: User opens deletion confirmation

- **WHEN** a signed-in user chooses Delete account and cloud data
- **THEN** Setline explains that the Setline account, cloud workout copy, and
  this browser's bound workout copy will be permanently removed

#### Scenario: User cancels confirmation

- **WHEN** the user cancels the confirmation
- **THEN** Setline closes the confirmation without making a deletion request or
  changing local data

### Requirement: Confirmed-outcome local handling

The system SHALL clear the deleted account's browser state only after the
server confirms deletion.

#### Scenario: Server confirms deletion

- **WHEN** the deletion endpoint confirms success
- **THEN** Setline clears the account-bound workout state, pending-sync marker,
  cached identity, device-only preference, and state-account binding before
  returning to account choice with a factual receipt

#### Scenario: Deletion request fails or is offline

- **WHEN** the deletion request fails, is rejected, or cannot reach the server
- **THEN** Setline keeps local state and account markers intact and tells the
  user that deletion could not be confirmed and the browser copy was kept

### Requirement: Accurate public retention choice

The public privacy notice SHALL describe the shipped self-service account and
cloud-data deletion behavior.

#### Scenario: Visitor reviews retention choices

- **WHEN** a visitor reads the privacy notice
- **THEN** it states that a signed-in user can permanently delete their Setline
  account and private cloud workout copy from the account menu
