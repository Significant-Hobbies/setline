# setline-workout-player Specification

## Purpose
TBD - created by archiving change add-setline-workout-player. Update Purpose after archive.
## Requirements
### Requirement: Programme overview
The system SHALL present a mobile-first dated programme overview with the
current block week, today's scheduled workout, expected duration, ordered
activity summary, and a direct start action. It SHALL also allow the user to
explicitly open another scheduled day from the programme view.

#### Scenario: User opens Setline before training
- **WHEN** the user opens the application without an active session between 27
  July and 18 October 2026
- **THEN** the system shows the matching week and local-calendar day's workout
  without requiring a network request

#### Scenario: User explicitly chooses another day
- **WHEN** the user selects a start action for a different programme day
- **THEN** the system starts that workout in its authored order without
  changing the programme schedule

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
  completed volume or duration

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
- **THEN** the visible remaining time reflects wall-clock time rather than the number of executed ticks

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

### Requirement: Authored 12-week programme
The system SHALL include Sarthak's dated 27 July–18 October 2026 strength,
cardio, and mobility programme with its seven-day weekly rhythm, written
exercise choices, preparation, cooldowns, and plan rules.

#### Scenario: User opens the programme
- **WHEN** the user reviews any week in the 12-week block
- **THEN** the system shows Monday Upper, Tuesday Lower, Wednesday Easy plus
  mobility, Thursday Upper plus hard cardio, Friday mobility, Saturday Lower,
  and Sunday Easy plus mobility

#### Scenario: Programme contains an equipment choice
- **WHEN** the written plan allows hack squat or leg press, machine or dumbbell
  shoulder press, or another explicit alternative
- **THEN** the system preserves that choice text without selecting an option for
  the user

### Requirement: Deterministic week rules
The system SHALL materialize only plan changes determined by the current block
week and SHALL leave readiness-based or optional changes under user control.

#### Scenario: User starts RDL in Week 1 or 2
- **WHEN** a Lower session resolves in Week 1 or Week 2
- **THEN** the authored sequence contains exactly two RDL working sets

#### Scenario: User starts hard cardio in Week 1 or 2
- **WHEN** Thursday hard cardio resolves in Week 1 or Week 2
- **THEN** the interval sequence contains exactly four hard rounds in their
  written order

#### Scenario: Conditional progression becomes eligible
- **WHEN** the programme reaches Week 3 or Week 5
- **THEN** the system shows the applicable RDL, pull-up-test, or lateral-raise
  condition without silently changing the executable workout

### Requirement: Multi-modality recording
The system SHALL record strength, bodyweight, duration, interval, mobility, and
completion-based steps using fields appropriate to the authored target.

#### Scenario: User completes a timed cardio segment
- **WHEN** the current step is prescribed by duration
- **THEN** the system records the completed duration and timestamp without
  requiring a fabricated weight or repetition value

#### Scenario: User completes a mobility drill
- **WHEN** the current step is prescribed by repetitions or a timed hold
- **THEN** the system shows that dose and records its completion in the ordered
  session
