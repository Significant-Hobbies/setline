## Why

Setline currently presents the authored programme accurately, but its execution
record is too rigid: one planned set can hold only one weight/repetition pair,
actual rest is not retained, and saved history loses the individual set ledger.
The product cannot become a trustworthy weekly analysis tool until it preserves
both the planned journey and what the user actually did.

## What Changes

- Keep the dated programme immutable while creating a session-specific
  execution queue that records deviations without rewriting future workouts.
- Let the user complete fewer or more repetitions, add an extra set, skip a
  step, or defer the current step until later in the same session.
- Let a weight-and-repetition set contain multiple contiguous segments, such as
  `60 kg × 5` followed by `50 kg × 3`, with volume calculated from every
  segment.
- Record when a set is completed and when the next set begins so planned rest,
  actual rest, and early/late starts remain separately visible.
- Persist the complete planned-versus-actual set ledger in device and cloud
  history instead of reducing a saved workout to aggregate totals.
- Add an end-of-session execution ledger showing completed, modified, added,
  deferred, and skipped work plus planned-versus-actual rest.
- Migrate stored state to a backward-compatible version that retains existing
  active sessions and summary history honestly when older detail is unavailable.
- Keep weekly analysis, cardio performance graphs, exercise substitution,
  arbitrary drag-and-drop reordering, and programme editing outside this pass.
  The new record shape will retain the timestamps and modality-specific values
  those later features require.

## Capabilities

### New Capabilities

- `workout-execution-records`: Session-only deviations, multi-segment and extra
  sets, actual cadence timestamps, and durable per-set history.

### Modified Capabilities

- `setline-workout-player`: The guided player distinguishes the immutable plan
  from the mutable execution queue and exposes cadence and deviation controls
  without weakening one-tap completion.

## Impact

- Updates Setline's local/cloud state envelope, validation, legacy migration,
  workout player, summary, history, and progress inputs.
- Requires a versioned data-model migration but no D1 schema migration because
  authenticated state is stored as a validated JSON document.
- Adds no production dependency and does not change Google Auth, the Cloudflare
  Worker binding surface, the programme source, or notification behavior.
- Uses the existing preserve-lane visual system; the primary action and ordered
  programme context remain dominant.
