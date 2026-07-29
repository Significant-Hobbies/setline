## ADDED Requirements

### Requirement: Planned and actual workout truth
The system SHALL preserve every authored programme step and target as immutable
plan data while recording session-specific execution separately. A deviation
MUST NOT rewrite the programme or a future scheduled workout unless the user
later performs an explicit programme-editing action outside the workout player.

#### Scenario: User changes a set result
- **WHEN** the user records a different weight, repetition count, duration, or
  RPE from the authored target
- **THEN** the system retains both the planned target and the actual result and
  identifies the set as modified

#### Scenario: User completes the next scheduled workout
- **WHEN** a previous session contained modified, extra, deferred, or skipped work
- **THEN** the next scheduled workout still resolves from the unchanged authored
  programme

### Requirement: Multi-segment strength sets
The system SHALL allow a weight-and-repetition execution to contain one or more
ordered segments. Each segment SHALL store its own weight and repetitions, and
volume SHALL be calculated as the sum of every valid segment.

#### Scenario: User performs a drop segment
- **WHEN** the user records `60 kg × 5` followed by `50 kg × 3` in one planned set
- **THEN** the system stores two ordered segments and calculates 450 kg of actual
  volume for that set

#### Scenario: User completes fewer repetitions
- **WHEN** the target is eight repetitions and the user records one segment of
  five repetitions
- **THEN** the system accepts the result as a completed modified set without
  fabricating the missing repetitions

### Requirement: Session-only extra sets
The system SHALL allow the user to add an extra execution of the current
exercise without adding a set to the authored programme. The extra execution
SHALL identify its source, actual position, tracking kind, and recorded values.

#### Scenario: User adds another working set
- **WHEN** the user selects Add another set after completing a working set
- **THEN** the system inserts an extra execution into the current session queue
  and leaves future workout templates unchanged

### Requirement: Explicit deferral and execution order
The system SHALL allow the current pending step to be deferred to the end of
the current session queue. It SHALL retain the authored position and separately
record the actual execution position.

#### Scenario: Equipment is temporarily unavailable
- **WHEN** the user selects Do later for the current pending step
- **THEN** the system moves that execution to the end of the session queue,
  advances to the next available step, and does not alter the authored plan

#### Scenario: User reviews a deferred workout
- **WHEN** a deferred step is later completed or skipped
- **THEN** history shows both its planned position and its actual execution
  position

### Requirement: Honest rest cadence
The system SHALL retain authored rest, any session-specific timer adjustment,
the previous completion timestamp, the next-step start timestamp, and calculated
actual rest as distinct values. Actual rest SHALL be based on wall-clock
timestamps and MUST NOT be inferred from countdown ticks.

#### Scenario: User starts the next set early
- **WHEN** the user starts the next set before the authored rest deadline
- **THEN** the system records the shorter actual rest and retains the authored
  rest target for comparison

#### Scenario: User starts after the timer finishes
- **WHEN** the rest timer reaches zero and the user waits before starting
- **THEN** the system includes the additional elapsed time in actual rest

#### Scenario: User adjusts the timer
- **WHEN** the user adds time, pauses the timer, or skips the remaining countdown
- **THEN** the system retains the authored target, the adjusted session target,
  and the eventual actual rest without treating them as the same measurement

### Requirement: Durable execution ledger
The system SHALL persist every planned, modified, extra, deferred, completed,
and skipped execution with its segments and cadence timestamps in device
history. Authenticated synchronization SHALL preserve the same detailed ledger
in the user's private cloud state.

#### Scenario: User reopens a saved workout
- **WHEN** the user opens a completed session from history
- **THEN** the system shows each set and segment with planned target, actual
  result, execution status, and available actual rest

#### Scenario: Older summary-only history is migrated
- **WHEN** version 3 history contains aggregate totals without individual sets
- **THEN** the system preserves those totals, marks set detail and cadence as
  unavailable, and does not synthesize records

### Requirement: Analysis-ready modality records
The system SHALL retain modality-specific actual values and timestamps without
reducing them to one unexplained intensity score. This pass SHALL support
strength segments, repetitions, duration, completion, and weight-duration
records while keeping the record contract extensible for later cardio fields.

#### Scenario: User completes a timed cardio step
- **WHEN** the user records a different duration from the cardio target
- **THEN** the detailed history retains planned duration, actual duration,
  start and completion timestamps, and execution position
