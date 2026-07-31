## ADDED Requirements

### Requirement: One bounded custom programme is persisted

The system SHALL let a device-only or authenticated user save at most one
named custom programme with an enabled state, Monday start date, 1–16 weeks,
and zero or one custom-workout assignment for each week/day slot.

#### Scenario: Valid programme is saved

- **WHEN** a user supplies a valid name, Monday start date, week count, and
  assignments that reference existing custom workouts
- **THEN** the programme is persisted through the existing device-first
  whole-state path without changing any workout template

#### Scenario: Invalid programme is submitted

- **WHEN** a programme has an invalid date, out-of-range week, duplicate slot,
  dangling workout reference, empty name, or exceeds a documented bound
- **THEN** the system rejects it without replacing the prior valid programme

### Requirement: Programme assignments are explicit and editable

The system SHALL let a user assign, replace, or clear each programme day and
SHALL treat an unassigned in-range day as explicitly unplanned.

#### Scenario: Workout is assigned to a day

- **WHEN** the user selects a custom workout for a week/day slot
- **THEN** that slot stores the template identifier while the template steps,
  targets, and authored order remain unchanged

#### Scenario: Assignment is cleared

- **WHEN** the user clears a populated slot
- **THEN** the day becomes explicitly unplanned and no workout template or
  recorded session is deleted

### Requirement: A week can be copied forward explicitly

The system SHALL let a user copy one week’s seven assignments into all later
weeks of the same programme.

#### Scenario: Later weeks already contain assignments

- **WHEN** copying forward would replace one or more later assignments
- **THEN** the system requires explicit confirmation before applying the copy

#### Scenario: Copy is confirmed

- **WHEN** the user confirms copying a source week forward
- **THEN** every later week receives the source week’s assignment pattern
  without changing the source week or any workout template

### Requirement: Enabled programme dates resolve deterministically

The system SHALL resolve an enabled programme by local calendar date using its
Monday start date and SHALL distinguish scheduled, unplanned, and out-of-range
days.

#### Scenario: Today has a scheduled custom workout

- **WHEN** the local date falls inside the programme and its week/day slot has
  an assignment
- **THEN** the resolver returns that custom workout and its programme week/day
  context

#### Scenario: Today is unplanned

- **WHEN** the local date falls inside the programme and its slot is empty
- **THEN** the resolver returns an explicit unplanned day instead of silently
  falling back to the bundled programme

#### Scenario: Programme does not apply

- **WHEN** the programme is paused or the local date is outside its range
- **THEN** the resolver returns out-of-range and the bundled programme remains
  the Today fallback

### Requirement: Existing state migrates safely

The system MUST migrate valid version 5 state to version 6 without changing its
session, history, or custom workouts and with no custom programme.

#### Scenario: Version 5 state is restored

- **WHEN** Setline restores a valid version 5 local, account, or backup state
- **THEN** it returns equivalent version 6 state with `customProgramme` set to
  null

