## ADDED Requirements

### Requirement: Programme overview
The system SHALL present a mobile-first weekly programme overview with today's scheduled workout, its expected duration, exercise count, and a direct start action.

#### Scenario: User opens Setline before training
- **WHEN** the user opens the application without an active session
- **THEN** the system shows today's workout and the weekly schedule without requiring a network request

### Requirement: Guided set execution
The system SHALL guide the user through the authored order of warm-up and
working sets while displaying one current set as the primary action. Exercise
and set positions SHALL remain stable during execution and in the saved record.

#### Scenario: User starts today's workout
- **WHEN** the user selects the start action
- **THEN** the system shows the first incomplete set with exercise name, set type, target, previous performance, rest duration, and form cues

#### Scenario: User completes a set
- **WHEN** the user records actual weight, repetitions, and optional RPE and selects Complete set
- **THEN** the system saves the values and completion timestamp with one primary action

#### Scenario: User skips a set
- **WHEN** the user selects Skip set
- **THEN** the system records the set as skipped and advances without adding completed volume

#### Scenario: Session advances through the plan
- **WHEN** the user completes or explicitly skips the current set
- **THEN** the system advances to the next authored position without silently
  reordering or jumping over another pending set

### Requirement: Honest warm-up and working records
The system SHALL preserve warm-up sets in session history while excluding them from working-volume calculations.

#### Scenario: Summary contains both set types
- **WHEN** a session includes completed warm-up and working sets
- **THEN** the system reports warm-up volume and working volume separately

### Requirement: Timestamp-derived rest timer
The system SHALL start rest automatically after a completed non-final set and derive remaining time from a stored end timestamp.

#### Scenario: Browser execution is delayed
- **WHEN** the app regains execution after a timer tick was throttled
- **THEN** the visible remaining time reflects wall-clock time rather than the number of executed ticks

#### Scenario: User adjusts rest
- **WHEN** the user adds 15 seconds, adds 30 seconds, or skips rest
- **THEN** the system updates the end timestamp or advances to the next set accordingly

### Requirement: Device-local continuity
The system SHALL persist active-session progress and completed-session history on the device without requiring an active network request.

#### Scenario: User reloads during a workout
- **WHEN** the user reloads Setline after completing at least one set
- **THEN** the system restores the active workout, completed results, and any in-progress rest deadline

### Requirement: Workout completion summary
The system SHALL summarize completed and skipped sets, duration, separate volume totals, average recorded RPE, and user-reported session quality.

#### Scenario: User completes the final set
- **WHEN** the final planned set is completed or skipped
- **THEN** the system presents the session summary and allows the user to save it to history

### Requirement: Basic progress view
The system SHALL show basic exercise progress using recorded values and clearly label calculated values.

#### Scenario: User reviews progress
- **WHEN** the user opens the progress view
- **THEN** the system shows recent recorded weight and repetition performance plus explicitly derived volume or change indicators

### Requirement: Accessible responsive operation
The system SHALL support keyboard navigation, visible focus, reduced motion, legible contrast, and layouts suitable for phone, tablet, and desktop widths.

#### Scenario: User operates Setline on a phone
- **WHEN** the viewport is approximately 390 pixels wide
- **THEN** the current set and primary completion action remain usable without horizontal scrolling
