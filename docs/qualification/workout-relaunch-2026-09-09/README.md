# Workout interruption and reopen qualification — 9 September 2026

The actual simulator UI exposed a history display defect: stored performed
positions were already one-based, but the view added one again. The first two
completed steps appeared as performed #2 and #3. The saved synthetic document
retained the correct positions and set values. The fix changes only the label;
there is no stored-data migration.

[Before](before-history.png) is a frame from the failing XCTest screen recording.
[Reopened history after the fix](after-reopened-history.png) shows the correct
performed #1/#2 and the exact recorded segments. [Resumed rest](after-resumed-rest.png)
shows the adjusted rest after termination and relaunch. The compact
[receipt](receipt.json) includes the original saved step values.

## Real UI journey

The test starts the authored Lower strength workout, records `5x40, 2x30`, adds
30 seconds to the authored 60-second rest, terminates, relaunches with the same
UUID fixture, and resumes. The adjusted 90-second rest survives, and the remaining
time does not reset. It records `4x55` on the next authored step, finishes, and
checks both exact recorded values and planned/performed #1/#2. The third planned
step has no performed position. A second termination/relaunch reopens the same
finished receipt, with no active workout left to resume.

The focused run passed all five tests with zero skips on Xcode 26.6 and the
isolated iOS 26.5 simulator. The original failed run also had a separate unit-host
bootstrap crash; those unit tests did not execute then. A fresh derived-data run
using the established test signing invocation passed all four fixture tests and
the unchanged UI assertions. The initial UI failure is not classified as a runner
failure.

## Fixture boundaries

The DEBUG-only `--ui-persistent-fixture UUID` launch uses its own temporary
UUID directory and defaults suite, seeds only when the file is absent, and
never replaces malformed existing bytes. Cloud/platform clients are nil and
notifications are inert. Invalid/path identifiers, reset demos and orphan cleanup
flags fail closed. Cleanup removes only that UUID directory and suite and starts
an inert recovery screen, without loading or reseeding a document. Unit tests
prove directory absence and preservation of a sibling fixture; XCTest teardown
runs cleanup even after assertion failures. The first failed fixture was separately
removed after its synthetic evidence was copied.

Release uses the existing application defaults. This proof does not qualify
physical workout use, real signed-in recovery, two-device iCloud convergence or
public distribution. Installed build 10/source `c4f9616` remains unchanged.
Those acceptance tasks stay in [issue 77](https://github.com/Significant-Hobbies/setline/issues/77).

## Required checks

`pnpm run check` passes. The full `pnpm quality:native` gate passes 239 tests,
including 18 UI tests, with one existing iCloud-credential skip and no failures.
Unsigned Release compilation passes. Production coverage is 11,842/14,532 lines
(81.4891%), above the unchanged 80.60% floor. No thresholds were relaxed.
After the terminal run, no Setline app remained running and a scoped scan found
zero remaining `setline-ui-*` fixture directories. The simulator slot was returned
to the other native lane.
