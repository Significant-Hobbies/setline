## ADDED Requirements

### Requirement: Custom workouts preserve execution semantics

The workout player SHALL treat a started custom template as authored plan data
and SHALL preserve all existing explicit skip, extra, partial/drop, deferral,
rest, and history semantics.

#### Scenario: Custom workout enters execution

- **WHEN** a valid custom template starts
- **THEN** each step is snapshotted as planned execution data in authored order
  and all later deviations remain explicit session records
