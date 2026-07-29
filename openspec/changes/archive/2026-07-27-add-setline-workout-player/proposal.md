## Why

Setline needs a focused first release that proves the PRD's core proposition: a lifter can open one mobile screen in the gym, follow a predefined session in order, log every set with minimal interaction, and trust the rest timer and history without a network connection.

## What Changes

- Add a new mobile-first Fleet web app named Setline.
- Provide a realistic weekly programme overview and a guided Upper A workout.
- Let the user start, complete, skip, and advance through warm-up and working sets.
- Start a rest timer from wall-clock timestamps after set completion, with add-time and skip controls.
- Record actual weight, repetitions, RPE, completion timestamps, and session progress in device-local storage.
- Show recent workout history and basic per-exercise progress derived from explicitly recorded data.
- Make the core experience responsive and installable as a PWA shell.
- Defer accounts, cloud sync, reminders, programme authoring/import, deterministic progression acceptance, and full analytics until the workout-player loop is validated.

## Capabilities

### New Capabilities

- `setline-workout-player`: Guided programme overview, active-workout execution, local set records, rest timing, and workout history.

### Modified Capabilities

None.

## Impact

- Adds `foundry/apps/setline/` as a new deployable Fleet app.
- Uses the approved pinned React, Next, Vinext, Vite, and Cloudflare starter runtime.
- Keeps workout records device-local in this release; no account, server database, secret, migration, or external integration is introduced.
- Adds a private Sites deployment surface after local validation.
