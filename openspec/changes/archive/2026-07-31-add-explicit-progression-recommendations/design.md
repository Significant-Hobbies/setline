## Context

The active player snapshots authored steps into a `WorkoutSession`, pre-fills actual-input segments from those snapshots, and retains completed `ExecutionRecord` details in local/account history. Setline distinguishes authored targets, user-recorded actuals, and app-calculated values, and it forbids silent programme rewrites.

## Goals / Non-Goals

**Goals:**

- Produce the same recommendation for the same current step and history.
- Use only the latest comparable session so an older successful workout cannot override a newer miss.
- Explain the exact completed sets, repetition threshold, RPE ceiling, and proposed load.
- Make Accept, Edit, and Keep current explicit.
- Apply accepted values only to the current execution's actual-input segment.

**Non-Goals:**

- Mutating bundled programmes, custom templates, or future sessions.
- Generating recommendations for warm-ups, bodyweight-only work, timed work, cardio, or completion steps.
- Coaching, failure/deload logic, plate inventory, unit conversion, or cloud persistence changes.

## Decisions

### Use a pure, history-derived recommendation

`getProgressionRecommendation(step, history)` will return either a fully explained recommendation or `null`. A pure module keeps the rule independently testable and prevents UI state from becoming product logic.

The rule considers only a current `Working` step tracked as `weight-reps` with positive authored weight, a repetition range, and an authored RPE ceiling. It locates the latest history entry containing comparable planned executions for the same normalized exercise name. Every comparable execution must be completed, contain one segment at the current authored load, reach the authored maximum repetitions, and record RPE at or below the ceiling. At least two comparable sets are required. A passing signal recommends `current load + 2.5 kg` at the authored minimum repetitions.

Alternatives considered:

- A single successful set was rejected as too noisy.
- Searching any older successful session was rejected because it can ignore a newer miss.
- Rewriting the programme or template was rejected because it violates Setline's execution-layer boundary.

### Keep decisions session-local and explicit

The player shows a calculated panel only for an eligible active execution. Accept copies the proposed load and minimum repetitions into that execution's actual segment. Edit reveals numeric inputs initialized from the proposal and applies the edited values only after confirmation. Keep current dismisses the panel for that execution and leaves the authored-prefilled actuals unchanged.

The authored target block remains unchanged and above the panel. Recommendation dismissal is presentation state; accepted or edited actuals persist through the existing session state.

### Preserve the existing visual language

The panel reuses the attempt board's ink rules, paper surface, condensed numerals, lime primary action, and existing secondary controls. It is labeled `CALCULATED` and uses factual copy so it cannot be mistaken for a recorded result or automatic coaching.

## Risks / Trade-offs

- [Exact exercise-name matching misses renamed equivalents] → Prefer false negatives to unsafe cross-exercise recommendations.
- [A fixed 2.5 kg step does not fit every implement] → Keep the rule narrow and allow Edit before applying.
- [Missing RPE suppresses recommendations] → Explain eligibility in the spec; never infer effort.
- [Dismissal returns after a page reload] → Accepted edits persist, while a non-mutating dismissal intentionally does not expand stored-state schema.
- [Multiple segments or extra sets can be valid training but ambiguous evidence] → Exclude them from this conservative first rule.

## Migration Plan

No stored-state or cloud migration is required. Rollback removes the pure module and player panel; existing session/history data remains valid.

## Open Questions

None for this bounded release.
