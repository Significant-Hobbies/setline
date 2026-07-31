## ADDED Requirements

### Requirement: Workout data transfer includes the custom programme

The workout-data envelope SHALL preserve the validated custom programme as
part of version 6 stored state and SHALL preview its identity and assignment
count before replacement.

#### Scenario: Programme backup is previewed

- **WHEN** a valid Setline export contains a custom programme
- **THEN** the preview reports its name, enabled state, start date, week count,
  and assignment count before explicit whole-state replacement

#### Scenario: Incoming programme has a dangling assignment

- **WHEN** an imported or synchronized programme references a custom workout
  absent from the same incoming state
- **THEN** the whole incoming state is rejected before the current device state
  changes

## MODIFIED Requirements

### Requirement: Workout data transfer includes custom templates

The workout-data envelope SHALL preserve the complete validated custom workout
template collection as part of version 6 stored state.

#### Scenario: Version 6 export is previewed

- **WHEN** a user selects a valid Setline export containing custom workouts
- **THEN** the preview reports the custom workout count before explicit
  whole-state replacement
