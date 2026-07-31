## ADDED Requirements

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

## MODIFIED Requirements

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
