## Why

Setline currently demonstrates one abbreviated sample workout, while the owner
has supplied a dated 12-week strength, cardio, and mobility plan intended for
real execution. The app should carry that plan faithfully so the PDF is no
longer needed in the gym.

## What Changes

- Replace the sample programme with Sarthak's 27 July–18 October 2026 plan,
  including all seven scheduled day types and the four weekly strength
  sessions.
- Encode every warm-up, exercise, cardio interval, mobility movement, rest
  period, cue, and working-set range in the authored order.
- Select the correct plan week and scheduled day from the calendar while still
  allowing an explicit workout to be opened from the programme view.
- Support weight/repetition, bodyweight, timed, interval, and completion-based
  steps in the same ordered workout player.
- Apply only deterministic week rules from the document, including two RDL
  sets in Weeks 1–2 and four hard-cardio rounds in Weeks 1–2. Conditional or
  optional changes remain visible recommendations and are never silently
  inserted.
- Migrate existing device/cloud state safely to the richer programme-aware
  session and history envelope without merging or reordering records.
- Quiet the current high-intensity presentation: retain safety lime for the
  active action, but let chalk, ink, spacing, and training-log structure carry
  the rest of the interface.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `setline-workout-player`: Expand the player from one sample strength workout
  to the supplied dated, week-aware, multi-modality programme while preserving
  exact authored order and offline continuity.

## Impact

- Setline programme definitions, session/history state, cloud-state
  validation, workout-player components, programme/today/history views, tests,
  product/design context, and PWA cache version.
- No new production dependencies, D1 tables, secrets, OAuth scopes, or external
  services.
