# custom-workout-templates Specification

## Purpose
TBD - created by archiving change add-custom-workout-templates. Update Purpose after archive.
## Requirements
### Requirement: Users can author ordered reusable workouts

The system SHALL let a device-only or authenticated user create and edit a
named custom workout containing one or more explicitly ordered exercise steps.

#### Scenario: User saves a valid workout

- **WHEN** the user supplies a workout name and valid ordered steps
- **THEN** the template is persisted through the existing device-first state
  path in exactly that authored order

#### Scenario: User submits invalid or unbounded content

- **WHEN** a workout has empty required fields, invalid targets, duplicate IDs,
  or exceeds template, step, string, or numeric bounds
- **THEN** the system rejects it without replacing the prior valid template

### Requirement: Duplication creates an independent copy

The system SHALL let a user duplicate a bundled or custom workout into a new
editable custom template with fresh template and step identifiers.

#### Scenario: Bundled workout is duplicated

- **WHEN** the user duplicates a bundled workout
- **THEN** a custom copy preserves its current name context, steps, targets,
  cues, rests, and order without changing the bundled source

#### Scenario: Copied workout is edited

- **WHEN** the user changes or deletes the custom copy
- **THEN** the source workout remains unchanged

### Requirement: Custom workouts use the existing offline player

The system SHALL start a custom workout through the same device-first session
player and immutable execution-record boundary used by bundled workouts.

#### Scenario: Custom workout starts offline

- **WHEN** the user starts a valid custom workout without network connectivity
- **THEN** the session begins with its authored steps in order and requires no
  network request

#### Scenario: Template changes after session start

- **WHEN** a custom template is edited or deleted after a session starts
- **THEN** the active session and completed history retain their original step
  snapshots

### Requirement: Template deletion clears programme assignments

The system SHALL remove all future custom-programme assignments that reference
a custom workout when that template is explicitly deleted.

#### Scenario: Scheduled template is deleted

- **WHEN** the user confirms deletion of a custom workout referenced by one or
  more programme slots
- **THEN** those slots become unplanned while active sessions and completed
  history retain their immutable snapshots

#### Scenario: Template is edited

- **WHEN** a scheduled custom workout is edited without changing its identifier
- **THEN** its programme assignments remain and a later session starts from the
  then-current template

### Requirement: Existing state migrates safely

The system MUST migrate valid version 4 and version 5 state to version 6
without changing its active session, history, or custom workout templates and
with no custom programme.

#### Scenario: Existing device opens the new version

- **WHEN** Setline restores valid version 4 or version 5 local or account state
- **THEN** it returns equivalent version 6 state, preserving custom workouts
  when present and setting `customProgramme` to null

### Requirement: Transfer and sync preserve custom workouts

The system SHALL include valid custom templates in the existing whole-state
device backup, preview/replace restore, and optional private account sync.

#### Scenario: Backup is restored

- **WHEN** a valid version 6 backup containing custom workouts is previewed and
  explicitly confirmed
- **THEN** those templates replace the current template collection with the
  rest of the incoming state

#### Scenario: Invalid template is present in incoming state

- **WHEN** a backup or account copy contains an invalid custom template
- **THEN** the whole incoming state is rejected before local state changes
