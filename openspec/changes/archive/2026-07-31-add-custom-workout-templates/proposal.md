## Why

Setline is positioned as the execution layer for user-authored programmes, but
the current Programme view can only start the bundled twelve-week plan. A user
cannot write a reusable workout or duplicate an existing workout before
adapting it.

## What Changes

- Add validated custom workout templates to Setline's versioned device/account
  state.
- Let a user create a named workout from an explicitly ordered list of exercise
  steps with tracking, targets, cues, and rest.
- Let a user duplicate a bundled or custom workout into a separate editable
  custom copy.
- Start custom workouts through the existing device-first session player.
- Keep active sessions and completed history as immutable snapshots when a
  template is changed or deleted.
- Include custom templates in the existing JSON backup, preview, restore, and
  whole-state account sync boundaries.

## Capabilities

### New Capabilities

- `custom-workout-templates`: Device-first creation, editing, duplication,
  deletion, and execution of ordered reusable workouts.

### Modified Capabilities

- `setline-workout-player`: Start a validated custom template without changing
  the offline execution or immutable-session contract.
- `workout-data-transfer`: Preserve custom templates through versioned backup
  and explicit whole-state restore.

## Impact

- Bumps local stored state from version 4 to version 5 with an additive,
  migration-safe `customWorkouts` collection.
- Adds pure validation/duplication helpers, authoring UI in Programme, and
  focused migration/render tests.
- Adds no dependency, Worker route, D1 migration, OAuth change, automatic
  programming, calendar scheduler, or deployment.
