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

### Missing Hub summary recovery (9 September 2026)

The decoder now accepts the Hub contract’s date-only and fractional-second
`occurredOn` values. A native coordinator regression reproduced the previous
loss: the cursor advanced while a valid summary never reached saved history.

In Settings, **Recover missing Hub summaries** checks the approved account’s
history through PersonalSyncKit `629d8e7`, including equal versions already
acknowledged by an older app. Existing local workouts and summaries are kept;
a removal during the request is not undone. Active workouts defer the operation.
Recovery cannot recreate set details that were never part of the Hub summary.

All pages must arrive and the local document must be saved before replay cursor
bookkeeping. Failed saves, interrupted pagination and cancellation remain
retryable. The shared limit is 100 pages of at most 500 changes, with no partial
history acknowledged. This action is opt-in and does not reset a live cursor.
Actual signed-in recovery, physical workout use and two-device iCloud convergence
remain in [issue 77](https://github.com/Significant-Hobbies/setline/issues/77).
Build 10 from recovery source `c4f9616` was installed on 9 September; installation
did not qualify a physical workout or signed-in recovery.
General quality passes with existing limits unchanged. Its development-only
ESLint dependency now resolves js-yaml 4.3.2, clearing the newly published high
advisory without adding a runtime dependency.

The final local XcodeBuildMCP gate passed 232 tests (17 UI), with the existing
iCloud-credential test skipped. Production coverage is 80.6953%
(11,675/14,468 lines), above the unchanged 80.60% floor.

Unsigned Release compilation also passed through XcodeBuildMCP on stable Xcode 26.6.

### Actual caller isolation proof (9 September 2026)

Two additional tests invoke `AppModel.approveHubAccount`, account restoration and
`syncWithPlatform` with memory-only synthetic identities and an isolated URL
session. Switching from A to B during a held response preserves A's queue and
document, rejects its downloaded summary/cursor, and records no successful sync.
Starting a workout and recording a set while a pull is held remains fully local;
the released response cannot commit history, cursor or success during that workout.
After an offline finish and reopen, explicit recovery preserves the native set
segments and imports exactly one tagged Hub summary. No new product defect was
reproduced by these scenarios.

The shared `31f6b4e` pin adds an explicit composition initializer for isolated
testing; default production connection behavior is unchanged. Installed build 10
from `c4f9616` remains unchanged. Real account/provider handoff, physical workouts,
iCloud convergence and public distribution remain in issue 77.

General quality passes. The full native suite passes 234 tests (17 UI), with the
existing iCloud-credential test skipped. Production coverage is 81.2483%
(11,755/14,468 lines), above the unchanged 80.60% floor.
Unsigned Release compilation also passes on stable Xcode 26.6.


### Workout interruption and detailed history (9 September 2026)

An actual isolated simulator workout now proves recording, adjusted rest,
termination/relaunch, resume, finish and a second reopen with exact set values
and authored/performed order. This exposed and fixed a display-only off-by-one:
performed positions were stored correctly as one-based but displayed with another
increment. Existing saves need no migration.

The DEBUG-only UUID fixture persists across relaunch without using owner data,
cloud, account clients or notifications. It refuses malformed paths/reset modes,
never reseeds an existing file, and cleans only its own directory/defaults.
Five focused UI/fixture tests pass. The [before/after receipt](docs/qualification/workout-relaunch-2026-09-09/README.md)
retains the real failed screenshot, saved values and corrected reopened history.
Physical workouts, real account recovery, iCloud convergence and distribution
remain in issue 77; installed build 10/source `c4f9616` was not changed.

The full required native gate passes 239 tests (18 UI), with the existing
credential test skipped; unsigned Release passes and coverage is 81.4891%
(11,842/14,532), above the unchanged 80.60% floor. General quality also passes.
