## Why

Custom workouts are reusable only when a user can place them into an explicit
calendar. Today they must be found and started manually, so Setline still
cannot represent the user-authored multi-week programme described by its core
product promise.

## What Changes

- Add one bounded, named custom programme with a Monday start date, 1–16 weeks,
  and seven explicit day slots per week.
- Let a user assign, replace, or clear a custom workout in each slot and copy a
  week’s assignments forward without changing any workout template.
- Let the user enable or pause the programme; while enabled and in range,
  Today resolves the matching scheduled custom workout or an explicit unplanned
  day.
- Clear future assignments when their referenced custom workout is deleted,
  while preserving active-session and history snapshots.
- Migrate stored state to version 6 and include the programme in existing
  device persistence, private whole-state sync, and JSON backup/restore preview.
- Add focused validation, migration, calendar-resolution, transfer, rendered
  contract, browser, responsive design, product, status, and changelog evidence.
- Keep multiple programme libraries, automatic generation, target progression,
  reminders, arbitrary import, deployment, D1 migration, OAuth, and production
  configuration out of scope.

## Capabilities

### New Capabilities

- `custom-programme-scheduling`: Bounded multi-week programme state, explicit
  custom-workout assignments, lifecycle rules, date resolution, and authoring
  behavior.

### Modified Capabilities

- `custom-workout-templates`: Deleting a custom workout also clears future
  programme assignments that reference it without changing recorded snapshots.
- `setline-workout-player`: Today can resolve an enabled custom programme slot
  and start its template through the existing offline player.
- `workout-data-transfer`: Versioned whole-state transfer includes the custom
  programme and reports it before replacement.

## Impact

- `app/lib`: a bounded schedule model, date resolution, stored-state v6
  migration, and transfer preview metadata.
- `app/page.tsx` and programme components: schedule authoring, explicit active
  state, and Today integration in the existing Setline visual system.
- Tests, OpenSpec, product/status/changelog truth, and preserve-mode screenshots.
- No new dependency, network requirement during workout execution, deployment,
  schema migration, authentication change, or production configuration.
