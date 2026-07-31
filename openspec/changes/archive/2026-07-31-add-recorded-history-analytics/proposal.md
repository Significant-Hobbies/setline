## Why

Setline's Progress page currently shows a static bench-press illustration even
when the user has saved real workout history. Replacing it with deterministic
history-derived exercise, workout, and programme views makes the record useful
without turning Setline into a coach or inventing adherence from absent data.

## What Changes

- Add a pure analytics layer over existing saved `HistoryEntry` data.
- Replace illustrative progress values with a recorded-history overview.
- Add selectable exercise evidence and a bounded recent-session trend from
  completed detailed executions.
- Add workout summaries grouped by stable workout identity.
- Add authored programme-week summaries plus an explicit custom-workout count.
- Keep legacy summary-only records limited to the aggregate fields they
  actually contain.
- Add honest empty states and recorded/calculated provenance throughout.

## Capabilities

### New Capabilities

- `recorded-history-analytics`: Deterministic overview, exercise, workout, and
  programme-week analytics derived from saved workout history.

### Modified Capabilities

- `setline-workout-player`: Replace the static basic Progress example with
  real, provenance-labeled recorded-history analytics.

## Impact

- A new pure client analytics module and focused tests.
- The existing Progress React surface and its preserve-lane styles.
- OpenSpec and `PROJECT_STATUS.md` durable product truth.
- No state-version change, dependency, server API, migration, or deployment.
