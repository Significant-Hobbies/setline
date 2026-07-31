## ADDED Requirements

### Requirement: Secondary workout-data management
The system SHALL expose workout-state transfer as a secondary Programme action
without changing active workout execution, primary navigation, or authored
programme order.

#### Scenario: User opens Programme management
- **WHEN** the user opens the Programme view without an active workout
- **THEN** data transfer appears after programme rules and does not displace the
  workout schedule or Start actions

#### Scenario: User is in an active workout
- **WHEN** a workout session is active
- **THEN** the player keeps the current execution as the primary surface and
  does not show import controls
