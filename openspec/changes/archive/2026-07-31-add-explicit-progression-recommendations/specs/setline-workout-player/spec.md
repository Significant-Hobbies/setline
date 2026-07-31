## ADDED Requirements

### Requirement: Progression choices are explicit and session-only

The active workout player SHALL show an eligible recommendation as calculated information below the unchanged authored target and SHALL offer Accept, Edit, and Keep current actions before recommendation values affect the current execution.

#### Scenario: User accepts the recommendation

- **WHEN** the user chooses Accept
- **THEN** the current execution's actual-input segment receives the suggested load and repetitions without changing the authored step, programme, template, future execution, or saved history

#### Scenario: User edits the recommendation

- **WHEN** the user chooses Edit, enters valid non-negative load and positive whole repetitions, and confirms
- **THEN** the current execution's actual-input segment receives the edited values without changing the authored target

#### Scenario: User keeps the current target

- **WHEN** the user chooses Keep current
- **THEN** the recommendation is dismissed for the current execution and its authored-prefilled actual values remain unchanged

#### Scenario: User is offline

- **WHEN** the active player has local history and no network connection
- **THEN** recommendation calculation and all three choices remain available

### Requirement: Recommendation provenance remains visually distinct

The player MUST label recommendation values and evidence as calculated and MUST not present them as recorded actuals or authored programme data.

#### Scenario: Authored and calculated values coexist

- **WHEN** an eligible recommendation appears
- **THEN** the authored target remains visible above it and the recommendation carries a visible Calculated provenance label
