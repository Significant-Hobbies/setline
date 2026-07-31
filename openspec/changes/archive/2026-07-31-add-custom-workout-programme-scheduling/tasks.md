## 1. Programme domain and persistence

- [x] 1.1 Add bounded custom-programme types, validation, local-date resolution, and copy-forward helpers with focused unit tests
- [x] 1.2 Upgrade stored state to version 6, migrate version 5 safely, and reject dangling programme assignments
- [x] 1.3 Include custom-programme identity and assignment counts in backup/import previews and transfer tests

## 2. Programme authoring

- [x] 2.1 Add an accessible responsive programme editor with name, Monday start, 1–16 weeks, enabled state, and seven assignment slots per week
- [x] 2.2 Add explicit copy-forward, shrink, delete, discard, navigation, and unload safeguards for authored changes
- [x] 2.3 Clear future programme assignments atomically when a referenced custom-workout template is deleted

## 3. Today integration

- [x] 3.1 Resolve Today against the enabled custom programme and show scheduled, unplanned, paused, and out-of-range states correctly
- [x] 3.2 Start scheduled custom workouts through the existing immutable offline session path with programme context

## 4. Verification and project truth

- [x] 4.1 Update rendered-source and regression tests for the programme editor, Today integration, and state version
- [x] 4.2 Update product documentation, changelog, and PROJECT_STATUS.md with the shipped custom-programme capability
- [x] 4.3 Run the manual Impeccable detector once, the smallest focused checks, full project check, strict OpenSpec validation, and design-review receipt
- [x] 4.4 Archive the completed OpenSpec change after all tasks and validations pass
