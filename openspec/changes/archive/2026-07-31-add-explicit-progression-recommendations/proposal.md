## Why

Setline records enough detailed working-set history to offer a small, explainable progression cue, but users currently have to compare prior sessions themselves. The product needs a deterministic recommendation that preserves the authored programme and requires an explicit choice before affecting the active session.

## What Changes

- Derive a conservative load recommendation from the latest comparable completed session for an exercise.
- Restrict evidence to completed, planned, single-segment, weight-and-repetition working sets at the current authored load.
- Recommend a 2.5 kg increase at the bottom of the authored repetition range only when every comparable set reached the top of the range at or below the authored RPE ceiling.
- Show the evidence and calculated recommendation in the active workout player.
- Require an explicit Accept, Edit, or Keep current action; accepted or edited values change only the current session's actual-input draft.
- Keep the feature device-first and offline, with no programme/template mutation, cloud schema, dependency, or deployment change.

## Capabilities

### New Capabilities

- `session-progression-recommendations`: Deterministic history-derived progression evidence and explicit session-only decision handling.

### Modified Capabilities

- `setline-workout-player`: The active working-set experience gains a calculated recommendation panel without changing the authored target.

## Impact

- Adds a pure recommendation module under `app/lib/`.
- Adds a bounded decision panel to the active workout player and matching styles.
- Adds focused unit coverage and updates product/status/changelog documentation on ship.
- Does not add dependencies, mutate stored history, change the cloud contract, or deploy.
