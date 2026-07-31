## ADDED Requirements

### Requirement: Deterministic history overview

The system SHALL derive overview totals only from saved history entries and
SHALL identify recorded source values separately from calculated aggregation.

#### Scenario: User has saved history

- **WHEN** the user opens Progress with one or more saved workouts
- **THEN** Setline shows the recorded session count and calculated total
  duration and working volume from those entries

#### Scenario: User has no saved history

- **WHEN** the user opens Progress without saved workouts
- **THEN** Setline explains how to create the first record and shows no
  fabricated example values

### Requirement: Exercise analytics from detailed executions

The system SHALL build exercise analytics only from completed executions in
history entries whose detailed records are available.

#### Scenario: Exercise appears with recorded weight and repetitions

- **WHEN** completed detailed weight-and-repetition executions share the same
  normalized exercise identity
- **THEN** Setline groups them as one exercise, preserves a recorded display
  name, and calculates latest evidence, best load and repetitions at that
  load, working volume, and a recent-session trend

#### Scenario: Different exercise identities exist

- **WHEN** detailed history contains exercises with different normalized names
- **THEN** Setline keeps them separate and offers keyboard-accessible exercise
  selection

#### Scenario: Record lacks detailed executions

- **WHEN** a legacy summary-only history entry is present
- **THEN** it contributes no exercise sets, loads, repetitions, or trend points

### Requirement: Workout analytics by stable identity

The system SHALL group saved workouts by `workoutId` and calculate only
available aggregate history values.

#### Scenario: Workout is recorded more than once

- **WHEN** multiple history entries share a workout identity
- **THEN** Setline shows the recorded count and latest date plus calculated
  average duration, total working volume, and resolved-set outcomes

#### Scenario: Workout name changes

- **WHEN** records with one workout identity contain different names
- **THEN** Setline uses the newest recorded name without splitting the group

### Requirement: Programme-week analytics without inferred adherence

The system SHALL summarize recorded built-in programme sessions by authored
week and SHALL keep custom-workout records separate.

#### Scenario: Built-in sessions span programme weeks

- **WHEN** saved built-in workouts contain authored week numbers
- **THEN** Setline shows recorded session and execution outcomes for each
  represented week in chronological week order

#### Scenario: A programme week has no saved history

- **WHEN** no entry exists for a programme week
- **THEN** Setline does not label that week missed, incomplete, or
  non-adherent

#### Scenario: Custom workouts are recorded

- **WHEN** one or more saved workout ids are custom
- **THEN** Setline reports their recorded count separately and does not assign
  them to the bundled programme-week summary

### Requirement: Bounded and honest presentation

The system SHALL keep analytics bounded, deterministic, and explicit about
measurement provenance.

#### Scenario: Long history exists

- **WHEN** an exercise has more than eight recorded sessions
- **THEN** the visible trend contains only the newest eight in chronological
  order while lifetime best and total calculations use all eligible history

#### Scenario: Metric is unavailable

- **WHEN** the saved record cannot support a calculation
- **THEN** Setline labels the value unavailable instead of estimating it
