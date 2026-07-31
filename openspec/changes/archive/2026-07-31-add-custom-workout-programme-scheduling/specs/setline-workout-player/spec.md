## ADDED Requirements

### Requirement: Today reflects the active custom programme

The Today view SHALL show the resolved scheduled custom workout or explicit
unplanned state when an enabled custom programme applies to the local date.

#### Scenario: Scheduled workout starts from Today

- **WHEN** Today resolves a valid custom-workout assignment and the user starts
  it
- **THEN** the existing offline player snapshots and executes that template in
  authored order with its programme week/day context

#### Scenario: Today is explicitly unplanned

- **WHEN** Today resolves an empty in-range custom-programme slot
- **THEN** the view identifies the day as unplanned and does not offer a bundled
  workout as if it belonged to the custom programme

#### Scenario: Custom programme is paused

- **WHEN** the saved custom programme is disabled
- **THEN** Today uses the existing bundled programme without changing or
  deleting the saved custom programme

