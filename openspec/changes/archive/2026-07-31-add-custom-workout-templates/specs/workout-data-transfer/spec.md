## ADDED Requirements

### Requirement: Workout data transfer includes custom templates

The workout-data envelope SHALL preserve the complete validated custom workout
template collection as part of version 5 stored state.

#### Scenario: Version 5 export is previewed

- **WHEN** a user selects a valid Setline export containing custom workouts
- **THEN** the preview reports the custom workout count before explicit
  whole-state replacement
