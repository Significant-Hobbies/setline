# Setline Project Status

## Why / What

Setline helps people execute a structured workout programme precisely without referring to another document or deciding what to do between sets. The user controls the programme; Setline presents the current action, records explicit results, controls rest, and separates recorded values from calculations.

The first release is a mobile-first web/PWA workout player. It includes
Sarthak’s dated 12-week strength, cardio, and mobility programme, device-first
session execution, optional Google sign-in with a private account copy, basic
history, and progress. It excludes coaching, automatic programme generation,
social features, meal/recovery tracking, sensors, Apple Health, and Apple Watch.

## Dependencies

- React, Next.js, and Vinext for the web application.
- Vite and the Cloudflare plugin for the Worker build.
- Better Auth with Google OAuth and native Sign in with Apple for optional
  identity; existing accounts use an explicit linking flow rather than
  email-based implicit linking.
- Cloudflare Workers and D1 for authenticated, user-scoped state.
- Browser `localStorage`, Service Worker, vibration, and installation APIs where supported.
- No email provider, paid service, sensor, or native runtime dependency.

## Timeline

- 2026-08-12 — shipped the native account connection path on the personal
  Apple and Cloudflare accounts: native Sign in with Apple, explicit existing
  Google-account linking, Keychain-backed sessions, private workout sync, and
  the additive D1 handoff/state migration. The production Worker is tagged to
  the exact main commit; App Store Connect record creation and TestFlight upload
  remain external release gates.
- 2026-08-11 — prepared the first native SwiftUI iPhone beta with complete
  local-first workout execution, planning, history, data transfer,
  accessibility, simulator coverage, App Store metadata, and a personal-team
  signed archive path; native account synchronization remains tracked
  separately.
- 2026-07-31 — replaced static progress examples with recorded-history
  analytics for exercises, workouts, and represented programme weeks, including
  bounded trends, honest legacy/empty boundaries, and explicit measurement
  provenance.
- 2026-07-31 — added fresh-session-protected self-service Setline account and
  private cloud-data deletion with explicit confirmation, outcome-safe browser
  cleanup, and accurate Google revocation guidance; no migration or deployment
  was performed.
- 2026-07-31 — added deterministic progression recommendations for eligible
  weight-and-repetition working sets, with visible latest-session evidence and
  explicit Accept, Edit, or Keep current actions that never rewrite authored
  targets.
- 2026-07-31 — added one bounded 1–16 week custom programme with explicit
  Monday-based workout assignments, copy-forward authoring, enabled/paused
  state, calendar-correct Today resolution, and version 6 whole-state transfer.
- 2026-07-31 — added device-first custom workout authoring and independent
  duplication with ordered, modality-aware exercise targets; session and
  history snapshots remain unchanged after template edits or deletion.
- 2026-07-31 — added a versioned local JSON workout-data export and bounded
  import preview with explicit whole-state replacement; no account credentials
  or server-side data are included.
- 2026-07-31 — stabilized the server-rendered account shell so hydration no
  longer introduces a late LCP heading; production-equivalent mobile
  Lighthouse reached 99 with 1.81s LCP and zero CLS, while production
  deployment remains manual.
- 2026-07-31 — prepared and locally verified public agent discovery for the
  product, changelog, privacy, and terms surfaces without exposing private
  workout state; production deployment remains separate.
- 2026-07-30 — made the repository independently operable by removing its
  sibling Fleet release dependency while preserving the full local check and
  SHA-tagged manual Worker deploy contract.
- 2026-07-30 — Made the canonical GitHub repository publicly readable. This
  changes source visibility only; authenticated workout data remains private
  and no deployment, DNS, or licensing change was made.
- 2026-07-29 — Added an owned `/changelog` with verified release outcomes and
  direct GitHub Roadmap and Source links.
- 2026-07-27 — Scoped and built the first Setline workout-player release from the supplied PRD.
- 2026-07-27 — Published version 1 as an owner-only Sites deployment.
- 2026-07-27 — Added optional Google sign-in, private D1 synchronization,
  public legal surfaces, and a guarded Cloudflare Worker release path.
- 2026-07-28 — Loaded the supplied 12-week programme in authored exercise order
  and refined the visual system to reserve lime for active actions and status.
- 2026-07-28 — Released flexible session execution with partial/drop segments,
  extra and deferred sets, actual rest cadence, and detailed history.
- 2026-07-29 — Moved Setline out of Fleet Workspace into the private
  `Significant-Hobbies/setline` repository with its product history, status,
  specifications, and GitHub issue queue. Fleet retains catalog and monitoring
  links only. No deployment or DNS change was performed.

## Products

- `ios/` — native SwiftUI iPhone beta for local-first workout execution;
  App Store Connect/TestFlight transport remains manual.
- Repository root — installable mobile-first Setline web app.
- [Public GitHub repository](https://github.com/Significant-Hobbies/setline) —
  canonical source, product planning, and issue owner.
- `https://setline.significanthobbies.com` — live Cloudflare Worker production
  surface.
- [Private Sites deployment](https://setline-workout.sarthak927.chatgpt.site) —
  owner-only rollback copy.

## Features (shipped)

- Native iPhone workout player with authored-order snapshots, activity-specific
  recording, drop segments, skips, session-only extras, deferrals,
  timestamp-derived rest, relaunch recovery, planning, history, progression,
  data transfer, accessibility, simulator tests, and personal-team archiving.
- Public editorial product changelog at `/changelog`.
- Dated seven-day schedule for the supplied 12-week strength, cardio, and
  mobility programme.
- Exact authored exercise and set order across Upper, Lower, easy cardio, hard
  cardio, mobility, preparation, and cooldown work.
- Week-aware RDL volume, hard-cardio rounds, and pull-up checkpoints.
- Guided warm-up, working-set, cardio, mobility, and cooldown execution.
- One-tap completion with modality-specific weight, repetitions, duration,
  completion status, and optional RPE inputs.
- Set skipping and ordered session rail.
- Timestamp-derived automatic rest timer with pause, add-time, and skip/start controls.
- Device-local active-session continuity and workout history.
- Versioned JSON download plus validated, bounded import preview and explicit
  whole-state replacement for local workout data.
- Optional Google sign-in with one private, user-scoped D1 state copy.
- Fresh-session-protected self-service account deletion that removes linked
  auth records and the private workout copy through existing D1 cascades, then
  reports browser cleanup separately.
- Device-first changes with offline retry and deterministic whole-state
  reconciliation.
- Explicit state validation that preserves authored exercise and set order.
- Public privacy notice and terms of use.
- Honest summary with separate warm-up/working volume and calculated provenance.
- Basic bench target context plus local recorded-volume signal.
- Deterministic progression recommendations from the latest comparable
  completed session, with calculated provenance and explicit session-only
  Accept, Edit, or Keep current decisions.
- Responsive phone, tablet, and desktop layouts.
- PWA manifest, install metadata, service-worker shell, and offline-friendly local operation.
- Immutable authored plans with a separate session execution queue.
- Partial and drop-set segments such as `60 kg × 5` followed by `50 kg × 3`.
- Session-only extra sets, explicit Do later deferral, and preserved planned and
  actual execution positions.
- Authored, adjusted, and actual rest retained separately from wall-clock
  completion and next-start timestamps.
- Detailed per-set execution history preserved on device and in authenticated
  cloud state.
- Recorded-history analytics with normalized exercise identity, metric-aware
  newest-eight trends, lifetime bests and volume, workout aggregates, and
  represented bundled programme-week summaries; custom workouts stay separate
  and missing history is never treated as missed training.
- Bounded custom workout templates with ordered exercise authoring, edit,
  independent duplication from bundled or custom workouts, confirmed deletion,
  and the existing offline-first workout player.
- Custom templates included in private whole-state sync and versioned JSON
  backup/restore, while active sessions and history retain immutable snapshots.
- One named 1–16 week custom programme with explicit seven-day assignments,
  confirmed copy/shrink/delete actions, and enabled or paused state.
- Calendar-correct Today resolution for scheduled custom workouts and explicit
  unplanned days, with scheduled sessions retaining programme week/day context.
- Programme assignments reference custom templates, clear atomically when a
  template is deleted, and travel in private sync and JSON backup/restore.

## Work queue

Open work is tracked only in
[GitHub Issues](https://github.com/Significant-Hobbies/setline/issues).
An open issue is a to-do, a linked pull request is in progress, and merge plus
issue closure makes the work done.
