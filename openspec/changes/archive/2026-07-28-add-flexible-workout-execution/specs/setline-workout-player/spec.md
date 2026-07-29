## MODIFIED Requirements

### Requirement: Guided set execution
The system SHALL guide the user through a session execution queue initially
derived from the authored order of preparation, warm-up, working, cardio,
mobility, and cooldown steps while displaying one current step as the primary
action. The authored positions SHALL remain stable as plan data, while explicit
skip, extra-set, and defer actions SHALL be recorded as actual execution data.

#### Scenario: User starts today's workout
- **WHEN** the user selects the start action
- **THEN** the system shows the first pending execution with its authored
  position, name, type, target dose, rest duration, and applicable form cues

#### Scenario: User completes a set
- **WHEN** the user records the fields applicable to the current execution and
  selects Complete
- **THEN** the system saves its segments, values, start and completion
  timestamps with one primary action

#### Scenario: User skips a set
- **WHEN** the user selects Skip
- **THEN** the system records the execution as skipped and advances without
  adding completed volume or duration

#### Scenario: Session advances through the plan
- **WHEN** the user completes or explicitly skips the current execution
- **THEN** the system advances to the next item in the current session queue
  without silently altering either the queue or authored positions

#### Scenario: User explicitly changes the session journey
- **WHEN** the user adds an extra set or defers the current execution
- **THEN** the system updates only the session queue and visibly identifies the
  deviation from the authored plan

### Requirement: Honest warm-up and working records
The system SHALL preserve warm-up sets and all their actual segments in session
history while excluding their segment volume from working-volume calculations.

#### Scenario: Summary contains both set types
- **WHEN** a session includes completed warm-up and working sets with one or
  more actual segments
- **THEN** the system reports warm-up volume and working volume separately from
  the detailed ledger

### Requirement: Timestamp-derived rest timer
The system SHALL start rest automatically after a completed non-final
execution, derive remaining time from a stored deadline, and record actual rest
when the next execution begins.

#### Scenario: Browser execution is delayed
- **WHEN** the app regains execution after a timer tick was throttled
- **THEN** the visible remaining time reflects wall-clock time rather than the
  number of executed ticks

#### Scenario: User adjusts rest
- **WHEN** the user adds 15 seconds, adds 30 seconds, pauses, or skips rest
- **THEN** the system updates the session timer target while retaining the
  authored rest target

#### Scenario: User starts the next execution
- **WHEN** the user selects Start next step before or after the timer reaches zero
- **THEN** the system timestamps the next execution start and calculates actual
  rest from the previous completion timestamp

### Requirement: Device-local continuity
The system SHALL persist the programme-aware execution queue, detailed active
records, and detailed completed-session history on the device before any
network request. In authenticated mode it SHALL reconcile the same versioned
state with the current user's private cloud record.

#### Scenario: User reloads during a workout
- **WHEN** the user reloads Setline after modifying, deferring, adding, or
  completing at least one execution
- **THEN** the system restores the workout identity, authored positions,
  current queue, actual records, and any in-progress rest deadline

#### Scenario: User has a legacy sample workout in progress
- **WHEN** version 2 or version 3 device or cloud state contains a prior session
- **THEN** the system migrates its available records without changing their
  original order or inventing unavailable detail

### Requirement: Workout completion summary
The system SHALL summarize completed, modified, extra, deferred, and skipped
executions; workout duration; separate volume totals; planned-versus-actual
rest; average recorded RPE; and user-reported session quality. It SHALL retain
the complete execution ledger when the session is saved.

#### Scenario: User completes the final queued execution
- **WHEN** the final current-session execution is completed or skipped
- **THEN** the system presents aggregate metrics and the planned-versus-actual
  ledger before saving the complete record to history
