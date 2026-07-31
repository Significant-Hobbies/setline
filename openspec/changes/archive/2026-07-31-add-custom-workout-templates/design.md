## Context

Bundled workouts are resolved from code for a programme week and day. Once a
workout starts, Setline snapshots every planned step into the active session;
history later retains those execution records. That snapshot boundary already
provides the right guarantee for editable templates: future template changes
must not rewrite an active or completed workout.

Setline persists one validated `StoredState` locally and optionally syncs that
same whole state to a private account copy. JSON transfer also serializes this
state, so custom templates belong inside it rather than in a second store.

## Goals / Non-Goals

**Goals:**

- Create and edit a reusable workout with explicit ordered steps.
- Duplicate a bundled or custom workout without linking the copy to its source.
- Start a custom workout in the existing offline session player.
- Migrate version 4 state safely and preserve templates through transfer/sync.
- Bound template count, step count, strings, and numeric targets.

**Non-Goals:**

- A multi-week calendar or programme scheduler.
- Automatic exercise selection, progression, or target changes.
- Arbitrary third-party import formats.
- Mutating active sessions or history after template edits.
- D1 schema changes or deployment.

## Decisions

### Extend the one validated state boundary

Version 5 adds `customWorkouts` to `StoredState`. Version 4 migrates with an
empty collection. Each template has a `custom:` ID, name, expected duration,
ordered `PlannedStep` snapshots, notes, and timestamps.

Account sync and JSON transfer need no parallel merge algorithm because both
already replace one validated whole-state copy.

### Reuse the session snapshot boundary

Starting a custom template calls `makeWorkoutSession` with the selected
template. The session contains its own ordered step snapshots. Editing or
deleting the template later cannot affect that session or completed history.

### Keep authoring explicit and bounded

The author selects tracking kind and enters only relevant targets. Step order
changes only through visible move controls. Validation rejects empty names,
empty workouts, duplicate IDs, invalid targets, unbounded strings, more than 50
templates, or more than 100 steps per template.

Duplication creates fresh template and step IDs and appends “copy” to the
workout name. It never changes the source.

### Preserve the operational visual language

Authoring lives beneath the existing Programme overview as a secondary
instrument panel. The workout list stays dense and ordered; lime remains
reserved for the primary save/start action, destructive actions require
confirmation, and every control meets the 44-pixel touch floor.

## Risks / Trade-offs

- **Old local/account data becomes unreadable** → Explicit v4-to-v5 migration
  and round-trip tests.
- **Template edits rewrite evidence** → Sessions/history retain snapshots and
  never resolve a custom template after start.
- **Malformed backup creates unusable workouts** → Reuse strict state parsing
  with field/count bounds before preview or replacement.
- **One-page UI becomes dense** → Keep the editor collapsed until create/edit,
  show one step form at a time, and review at 390, 768, and 1440 pixels.
