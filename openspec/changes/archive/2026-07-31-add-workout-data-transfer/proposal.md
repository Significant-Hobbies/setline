## Why

Setline keeps workout execution data device-first, but users cannot currently
take a safe copy with them or restore one without manipulating browser storage.
A validated export and preview-before-replace import gives users practical data
ownership without weakening the existing ordered-session or account boundaries.

## What Changes

- Add a versioned Setline workout-data JSON envelope that contains only the
  existing validated workout state and non-sensitive export metadata.
- Let users download their current device state as JSON without a network
  request.
- Validate file type, size, envelope version, and stored-state structure before
  presenting an import preview.
- Summarize the incoming active session and history before any local state is
  changed.
- Require an explicit replace confirmation; cancellation and invalid files
  leave current device and cloud state unchanged.
- Persist a confirmed import through the existing device-first whole-state
  path, including the normal signed-in sync retry behavior.
- Keep programme authoring, merging, account deletion, and cloud-only recovery
  out of scope.

## Capabilities

### New Capabilities

- `workout-data-transfer`: Versioned local workout-state export, bounded import
  validation, preview, and explicit whole-state replacement.

### Modified Capabilities

- `setline-workout-player`: Expose data transfer as a secondary programme
  management action while preserving active workout priority and offline use.

## Impact

- Affects the device-state library, the main Setline application surface,
  related styling, and state/render tests.
- Reuses the current `StoredState` validator and persistence/sync path.
- Adds no dependency, database migration, server route, credential access, or
  production deployment.
