## Purpose

Defines the observable behavior of Setline's native iPhone client, including workout parity, offline execution, synchronization boundaries, accessibility, and submission preparation.

## ADDED Requirements

### Requirement: Native workout execution preserves authored order
The iOS client SHALL start every workout from an immutable snapshot of the selected bundled or custom template and SHALL present exercises and planned sets in their authored order. It SHALL distinguish planned, completed, skipped, deferred, modified, and session-only extra work without rewriting the source template.

#### Scenario: User changes the active session
- **WHEN** the user skips a set, adds a session-only set, or moves the current step to Do later
- **THEN** the client records the deviation in the session while future workouts retain the authored template

### Requirement: Activity-specific recording is available
The iOS client SHALL support weight-and-repetition sets including ordered drop segments, repetition-only work, timed work, cardio duration or distance, and mobility doses. Recorded values SHALL remain distinct from authored targets and calculated values.

#### Scenario: User records a drop set
- **WHEN** the user records multiple ordered weight-and-repetition segments for one planned set
- **THEN** the client saves and displays every segment in order as one completed planned set

### Requirement: Rest cadence uses wall-clock timestamps
The iOS client SHALL retain the authored rest target, user adjustment, completion timestamp, next-step timestamp, and actual elapsed rest as separate values.

#### Scenario: App is backgrounded during rest
- **WHEN** the user backgrounds and later returns to the app during an active rest period
- **THEN** the displayed countdown and actual rest derive from timestamps rather than paused process time

### Requirement: Active workouts work offline and recover
Starting, recording, navigating, timing, and completing an active workout SHALL not require network access. An interrupted active workout SHALL restore its current position, recorded values, and running rest state after relaunch.

#### Scenario: Device loses connectivity mid-workout
- **WHEN** connectivity is unavailable after a workout starts
- **THEN** all workout actions remain usable and the completed session is retained locally

### Requirement: Native client provides current Setline planning and history surfaces
The iOS client SHALL provide Today and weekly schedule views, bundled and custom templates, bounded custom-programme scheduling, workout history, record detail, planned-versus-actual ledgers, basic progress summaries, and deterministic session-only progression recommendations requiring explicit user acceptance.

#### Scenario: User reviews a prior workout
- **WHEN** the user opens a completed session from History
- **THEN** the client shows its authored snapshot, recorded results, deviations, rest evidence, and provenance labels

### Requirement: Local data transfer and account controls are present
The iOS client SHALL support versioned whole-state export, preview-before-replace import, local data reset, optional account connection using existing Setline service contracts, synchronization status, sign out, and account deletion where the service supports it.

#### Scenario: User previews an import
- **WHEN** the user selects a compatible Setline export
- **THEN** the client validates and summarizes the replacement before requiring explicit confirmation

### Requirement: Native account access includes Sign in with Apple
The iOS client SHALL offer Sign in with Apple beside Google account connection. Apple identity tokens SHALL be verified by the service for the native bundle identifier. The service SHALL disable implicit email-based linking; an existing signed-in account MAY add Apple only through an explicit authenticated linking action.

#### Scenario: Existing Google user adds Apple
- **WHEN** an authenticated Google user chooses the Apple control and completes Apple's authorization
- **THEN** Apple is linked to that same account without replacing local workout data or inferring identity from matching email text

### Requirement: The native experience is accessible and honest
The iOS client SHALL support Dynamic Type, VoiceOver labels and values, Reduce Motion, sufficient contrast, 44-point targets, and status cues that do not rely on color alone. Unsupported sensor or health values SHALL be omitted or labelled unavailable rather than estimated.

#### Scenario: User enables accessibility settings
- **WHEN** the user enables a larger accessibility text size and Reduce Motion
- **THEN** primary workout actions remain reachable and state changes remain understandable without nonessential animation

### Requirement: Submission preparation stops before publication
The repository SHALL include privacy metadata, app icons, version/build configuration, support and privacy links or copy, automated tests, a simulator verification path, and a personal-team archive path. Preparation SHALL not create or modify App Store Connect records or upload a build.

#### Scenario: Maintainer prepares a release candidate
- **WHEN** the documented release checks and archive command complete
- **THEN** a locally verifiable archive and metadata checklist exist with publication left as a later manual action
