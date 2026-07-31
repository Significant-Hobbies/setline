## MODIFIED Requirements

### Requirement: Basic progress view

The system SHALL show deterministic overview, exercise, workout, and
programme-week analytics using recorded history and SHALL clearly label
recorded source values, calculated aggregations, and unavailable detail.

#### Scenario: User reviews progress

- **WHEN** the user opens the Progress view with saved history
- **THEN** the system shows recorded session evidence, recent exercise
  performance, workout aggregates, and represented programme-week outcomes
  without collapsing them into a coaching score

#### Scenario: User has no progress record

- **WHEN** the user opens Progress before saving a workout
- **THEN** the system shows an honest empty state without illustrative training
  results
