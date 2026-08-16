# Setline Project Status

## Why / What

Setline helps people execute a structured workout programme precisely without referring to another document or deciding what to do between sets. The user controls the programme; Setline presents the current action, records explicit results, controls rest, and separates recorded values from calculations.

The first release is an iOS-native workout player with no backend of its own. It
includes Sarthak’s dated 12-week strength, cardio, and mobility
programme resolved natively on device, structured set targets, multi-segment set
recording, a set timer alongside the rest timer, a bundled movement catalogue
spanning strength, stamina, mobility and flexibility, and per-exercise measured
current values against authored targets. It excludes coaching, automatic
programme generation, social features, meal/recovery tracking, and sensors.

Apple Health, Apple Watch, CrossFit session formats, range-of-motion
assessments, iCloud sync, and on-device workout generation are planned rather than
shipped. Until iCloud sync lands, training lives only on the device that recorded
it, and the versioned JSON export is the only way to move or back it up.

## Dependencies

- SwiftUI native iPhone app for workout execution, with Swift Charts for trends
  and local notifications for rest completion.
- A JSON document in the app’s own container. No database, no account, no request
  during a workout.
- GitHub Pages for the static public site and its agent surfaces. Nothing the app
  does depends on it, and it costs no account to maintain.
- Node’s built-in test runner for the static-surface contracts; XCTest for
  everything the app does.
- No backend, email provider, paid service, sensor, or third-party runtime
  dependency.

## Timeline

- 2026-08-16 — left Cloudflare entirely. Deleted the live `setline` Worker and the
  `setline` D1 database, which held zero rows in every table because no one ever
  signed in. Removed wrangler, the Cloudflare-only `_headers` and `_redirects`, and
  the deploy script. The public site is now published by GitHub Pages from
  `public/` with its own CNAME. Setline holds no Cloudflare resources and no
  hosting account. `setline.significanthobbies.com` returns 530 until a CNAME to
  `significant-hobbies.github.io` is added and Pages publishes.

- 2026-08-16 — removed the Cloudflare Worker backend and every trace of the
  account layer: Better Auth with Google and Apple sign-in, D1-backed private
  state, the MCP read surface, the whole-document sync and conflict flow, 3,277
  lines of superseded TypeScript, and 12 test files covering it. Setline is now
  device-first with no server of its own. The public site became static Pages
  content carrying its own headers, and the service worker was replaced with one
  that evicts the shell of the deleted web app. The sync invariant that the
  removed cloud type used to guard is preserved as a document-level contract.

- 2026-08-16 — replaced the placeholder landing page with a real one built to the
  fleet landing standard on the app's own tracked palette: hero, product
  screenshots, four-pillar breakdown, a refusals section, fit guidance and a FAQ,
  with honest pre-release status and no store link. Agent-indexing surfaces were
  rewritten to match, and a test now holds the sitemap, the agent catalogue and
  the files on disk to one another so no surface can drift. Removed all six
  duplicated blocks in the native sources and split the two longest new
  functions; duplication is now zero.

- 2026-08-16 — replaced free-text set targets with a structured target model and
  ported the dated 12-week programme into the native app, which previously
  shipped only a two-template placeholder. Added a bundled movement catalogue
  across all four pillars, per-exercise measured current values with authored
  targets and trend charts, repeatable multi-segment set recording with a
  shorthand parser, a set timer independent of rest, rest-completion
  notifications, and authored double-progression rules. Version 2 of the local
  document reads version 1 without losing recorded work.

- 2026-08-15 — removed the Next.js web app and went iOS-first. The Cloudflare Worker API backend (auth, native state, MCP, agent-edge) remains unchanged. Static HTML pages in public/ replace the web UI. Shared business logic moved from app/lib/ to src/lib/.

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
- Static public site in `public/` (landing, privacy, terms, changelog) plus the
  agent surfaces `index.md`, `llms.txt`, `llms-full.txt`, `sitemap.xml`,
  `robots.txt` and `/api/ai`, published by GitHub Pages on push to `main`. The
  canonical hostname is dark until its DNS record points at GitHub Pages.
- [Public GitHub repository](https://github.com/Significant-Hobbies/setline) —
  canonical source, product planning, and issue owner.
- `https://setline.significanthobbies.com` — canonical public surface, pending a
  DNS record to GitHub Pages.
- [Private Sites deployment](https://setline-workout.sarthak927.chatgpt.site) —
  owner-gated (401) survivor of the removed web app. It is not a rollback path
  for the iPhone app and nothing depends on it.

## Features (shipped)

- Native iPhone workout player with authored-order snapshots, activity-specific
  recording, drop segments, skips, session-only extras, deferrals,
  timestamp-derived rest, relaunch recovery, planning, history, progression,
  data transfer, accessibility, simulator tests, and personal-team archiving.
- Public editorial product changelog at `/changelog`.
- Landing page stating audience, outcome, the four pillars, what the product
  refuses to do, poor-fit cases and real FAQs, with product screenshots and no
  claim of App Store availability.
- Dated seven-day schedule for the supplied 12-week strength, cardio, and
  mobility programme, resolved natively for every one of its 84 days.
- Structured set targets carrying rep ranges, absolute/relative/bodyweight/assisted
  load, reps in reserve, tempo, per-side work, and rest as a band rather than a
  scalar; warm-up sets are excluded from volume, records, and progression.
- Bundled movement catalogue with stable identities, muscle groups, equipment,
  and per-movement measurable metrics across strength, stamina, mobility, and
  flexibility, plus the CrossFit movement vocabulary.
- Per-exercise measured current values (estimated 1RM, top set load, max
  repetitions, best hold, longest distance, best pace, range of motion), each
  citing the session that produced it, against authored targets with progress,
  weekly rate, projected arrival, and trend charts.
- Repeatable multi-segment set recording so `5 reps × 40 kg` followed by
  `2 reps × 30 kg` records as one set, with a tested shorthand parser that shows
  its interpretation before anything is recorded.
- Set timer recording time under load independently of the rest timer.
- Rest-completion local notification so the timer survives leaving the app.
- Authored double-progression rules per movement, including the plan's own
  increments and its below-range regression case.
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
- Explicit state validation that preserves authored exercise and set order.
- Public privacy notice and terms of use.
- Honest summary with separate warm-up/working volume and calculated provenance.
- Deterministic progression recommendations from the latest comparable
  completed session, with calculated provenance and explicit session-only
  Accept, Edit, or Keep current decisions.
- Immutable authored plans with a separate session execution queue.
- Partial and drop-set segments such as `60 kg × 5` followed by `50 kg × 3`.
- Session-only extra sets, explicit Do later deferral, and preserved planned and
  actual execution positions.
- Authored, adjusted, and actual rest retained separately from wall-clock
  completion and next-start timestamps.
- Detailed per-set execution history preserved on device, with a versioned JSON
  export and a bounded import preview as the only way data leaves or enters.
- Recorded-history analytics with normalized exercise identity, metric-aware
  newest-eight trends, lifetime bests and volume, workout aggregates, and
  represented bundled programme-week summaries; custom workouts stay separate
  and missing history is never treated as missed training.
- Bounded custom workout templates with ordered exercise authoring, edit,
  independent duplication from bundled or custom workouts, confirmed deletion,
  and the existing offline-first workout player.
- One named 1–16 week custom programme with explicit seven-day assignments,
  confirmed copy/shrink/delete actions, and enabled or paused state.
- Calendar-correct Today resolution for scheduled custom workouts and explicit
  unplanned days, with scheduled sessions retaining programme week/day context.

## Work queue

Open work is tracked only in
[GitHub Issues](https://github.com/Significant-Hobbies/setline/issues).
An open issue is a to-do, a linked pull request is in progress, and merge plus
issue closure makes the work done.
