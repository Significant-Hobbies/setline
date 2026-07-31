## ADDED Requirements

### Requirement: Recommendation eligibility is deterministic and conservative

The system SHALL return a progression recommendation only for a current weight-and-repetition working step with a positive authored load, an authored repetition range, and an authored RPE ceiling.

#### Scenario: Eligible current step

- **WHEN** the current step is a weighted working set with minimum and maximum repetitions and a target RPE
- **THEN** the system evaluates recorded history for comparable evidence

#### Scenario: Ineligible modality

- **WHEN** the current step is a warm-up, bodyweight-only, timed, cardio, mobility, completion, or single-repetition-target step
- **THEN** the system returns no recommendation

### Requirement: Latest comparable session is the sole evidence source

The system MUST find the newest saved history entry containing planned, completed, single-segment weight-and-repetition working sets whose normalized exercise name matches the current step.

#### Scenario: Newer comparable session fails

- **WHEN** an older comparable session satisfies the progression rule but the newest comparable session does not
- **THEN** the system returns no recommendation

#### Scenario: Extra and multi-segment work is present

- **WHEN** a history entry includes extra executions or multi-segment executions for the exercise
- **THEN** those executions do not contribute progression evidence

### Requirement: Every comparable set must clear the authored threshold

The system SHALL recommend a 2.5 kg increase at the authored minimum repetitions only when at least two comparable sets exist and every comparable set used as evidence records the current authored load, at least the authored maximum repetitions, and an actual RPE no higher than the authored ceiling.

#### Scenario: All comparable sets clear the threshold

- **WHEN** at least two comparable sets all match the authored load, reach the repetition maximum, and do not exceed target RPE
- **THEN** the recommendation is the authored load plus 2.5 kg at the authored minimum repetitions

#### Scenario: One comparable set misses

- **WHEN** any comparable set has a different load, fewer than the maximum repetitions, missing RPE, or RPE above the ceiling
- **THEN** the system returns no recommendation

### Requirement: Recommendation evidence is explainable

The system MUST return the source workout timestamp, evidence-set count, prior load, repetition threshold, RPE ceiling, suggested load, and suggested repetitions with a successful recommendation.

#### Scenario: Recommendation is displayed

- **WHEN** the recommendation rule passes
- **THEN** the player can state exactly which latest session and completed-set threshold produced it
