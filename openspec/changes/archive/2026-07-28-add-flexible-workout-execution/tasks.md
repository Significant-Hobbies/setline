## 1. Versioned Execution Model

- [x] 1.1 Add version 4 execution, segment, queue, cadence, and detailed-history types plus strict validators.
- [x] 1.2 Add pure version 3 migration for active sessions and summary-only completed history without fabricating unavailable details.
- [x] 1.3 Add calculation helpers for segment volume, modification status, execution position, and planned-versus-actual rest.

## 2. Session Queue Behavior

- [x] 2.1 Build new sessions from immutable planned-step snapshots and a separate execution queue.
- [x] 2.2 Implement session-only extra-set insertion without changing programme templates.
- [x] 2.3 Implement explicit Do later deferral while retaining authored and actual positions.
- [x] 2.4 Update completion, skip, undo, correction, rest, reload, and cloud reconciliation paths for version 4 records.

## 3. Robust Workout Input

- [x] 3.1 Add ordered segment editing for weight-and-repetition sets with touch-friendly add, edit, and remove controls.
- [x] 3.2 Preserve one-tap completion for standard one-segment sets and clearly label modified, extra, deferred, and skipped executions.
- [x] 3.3 Add secondary Add another set and Do later actions without weakening the primary completion hierarchy.
- [x] 3.4 Keep duration, repetitions, completion, and weight-duration inputs compatible with the detailed execution record.

## 4. Cadence and Durable History

- [x] 4.1 Retain authored rest, adjusted timer target, previous completion, next-start timestamp, and actual rest separately.
- [x] 4.2 Show planned and actual rest on completed receipts and the end-of-session execution ledger.
- [x] 4.3 Save and render every execution and segment in device history and authenticated cloud state.
- [x] 4.4 Mark migrated summary-only workouts as lacking set and cadence detail instead of synthesizing records.

## 5. Verification and Design Review

- [x] 5.1 Add tests for split-set volume, partial targets, extra sets, deferral, cadence, detailed history, and version 3 migration.
- [x] 5.2 Browser-test standard completion, `60 × 5 + 50 × 3`, early/late rest, extra sets, deferral, reload, correction, and history reopening.
- [x] 5.3 Complete the preserve-lane design receipt, responsive evidence at 390/768/1440 pixels, critique, polish, audit, and detector passes.
- [x] 5.4 Run the full Setline check, Worker dry run, strict OpenSpec validation, dependency guard, and diff checks.

## 6. Release Closure

- [x] 6.1 Update `PRODUCT.md`, `DESIGN.md`, and `PROJECT_STATUS.md` with the planned-versus-actual execution contract and deferred analytics boundary.
- [x] 6.2 Archive this OpenSpec change after owner acceptance for the production release.
