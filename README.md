# Setline

Setline is a native iPhone workout player. Follow an authored programme, record
actual sets, control rest, and compare progress with targets you set. Active
workouts run and save on the device without waiting for a network request.

The app lives in [`ios/`](./ios). The public landing, privacy and support pages
are owned by the shared `ios-landings` factory (`PRODUCT=setline`), at
[setline.significanthobbies.com](https://setline.significanthobbies.com).
This repository has no separate landing source or product-specific backend.

## Using it

Start with Today or an authored workout. Complete sets in programme order and
record what happened. Skips, extra sets and Do later are explicit session
changes; they do not silently rewrite the programme. Completed workouts appear
in history, and You contains progress and periodic benchmark check-ins.

The app includes the owner-authored dated 12-week programme, custom workout
creation and duplication, one bounded 1–16 week custom programme, structured set
targets, partial/drop segments, set and rest timing, and a movement catalogue.
Load recommendations require an explicit choice and affect only the session.

Keep a versioned JSON export as a backup. It includes workout state, templates,
and the custom programme; import previews the replacement before applying it.
Private iCloud continuity is implemented, but two-device convergence remains
unverified on hardware. Optional Significant Hobbies Hub sync shares completed
session summaries after local writes. Neither is required to run a workout.

In Settings, approve existing history for the displayed Hub account before its
first sync. That approval persists locally; another account cannot upload those
workouts or take over waiting changes. Workouts received through iCloud retain
their recorded Hub owner. Finish an active workout before approving history.

Hub downloads commit locally before their sync cursor advances. Native workout
details are preserved when their summary returns from the Hub. Newly imported
summaries are labelled explicitly, carry no invented set data, and are not
uploaded again as new workouts. Untagged legacy records remain preserved when
a summary has the same ID. These guarantees are covered by synthetic native
tests; they do not establish physical signed-in convergence.

## Current installation evidence

Version 1.0.0 build 10 was built from CI-verified source `6c1b1f4`, checked with
codesign, installed and successfully launched on the owner's iPhone on
9 September 2026. Physical workout use and signed-in
synchronization remain unverified; launch does not establish TestFlight
availability or public enrollment. The current installation and actual-use
checklist lives in [issue 77](https://github.com/Significant-Hobbies/setline/issues/77).

## Local development and checks

```bash
pnpm install --frozen-lockfile
pnpm check                     # repository contracts and code health
pnpm quality:native            # generate, simulator tests, Release build, coverage
```

For native-only iteration, `ios/scripts/check.sh` also accepts
`SETLINE_SIMULATOR_DESTINATION` for an available iPhone simulator. Marketing
changes belong in `../ios-landings/products/setline/`, following that
repository's instructions.

## Retained work

Physical iPhone use, real iCloud convergence, and signed-in Hub continuity need
qualification. Apple Health, Apple Watch, CrossFit session formats,
range-of-motion assessments and on-device workout generation remain planned.
Coaching and social features are outside the current workout execution scope.

Source, product planning and GitHub Issues live in this repository. The private
Fleet catalog records evidence and release limits without owning this app.
