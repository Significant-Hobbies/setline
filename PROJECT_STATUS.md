# Setline Project Status

## Why / What

Setline helps people execute a structured workout programme precisely without referring to another document or deciding what to do between sets. The user controls the programme; Setline presents the current action, records explicit results, controls rest, and separates recorded values from calculations. A Benchmarks scorecard inside the You tab provides 15 periodic capability checkpoints — strength, endurance, movement, power, skills, and body composition — with editable targets, test protocols, and check-in snapshots that preserve the distinction between recorded, estimated, reported, and unknown values.

The first release is an iOS-native workout player with no backend of its own. It
includes Sarthak’s dated 12-week strength, cardio, and mobility
programme resolved natively on device, structured set targets, multi-segment set
recording, a set timer alongside the rest timer, a bundled movement catalogue
spanning strength, stamina, mobility and flexibility, per-exercise measured
current values against authored targets, and a periodic Benchmarks scorecard
with check-in history. It excludes coaching, automatic
programme generation, social features, meal/recovery tracking, and sensors.

Apple Health, Apple Watch, CrossFit session formats, range-of-motion
assessments, and on-device workout generation are planned rather than shipped.
iCloud sync is implemented on this branch — per-record CloudKit in the user's
private database, with a pure merge, a Settings status, and launch/foreground
reconcile — but two-device convergence has not been checked on hardware, so it
is not claimed as shipped. The versioned JSON export remains the backup.

## Dependencies

- SwiftUI native iPhone app for workout execution, with Swift Charts for trends
  and local notifications for rest completion.
- A JSON document in the app’s own container. No request runs during a workout.
- PersonalSyncKit and Personal Platform for optional signed-in completed-session sync.
- Cloudflare Pages (`setline`) for the static public site from the
  ios-landings factory. Nothing the app does depends on it.
- Node’s built-in test runner for the static-surface contracts; XCTest for
  everything the app does.
- No product-specific backend, email provider, paid service, sensor, or analytics SDK.

## Timeline

- **2026-09-09** — Build 10 adds explicit, durable Hub account approval. Local
  history and waiting sync changes require approval before adoption; history
  already owned by another account is excluded from upload. Session ownership
  survives the existing iCloud payload, and new offline workouts inherit the
  approved owner. Downloads validate the current account around local commit;
  active workouts refuse approval and incoming commits. Eight new core/app
  regressions cover ownership, legacy decoding, iCloud payload round trips,
  durable save failure/retry, account mismatch, and active-session preservation.
  `pnpm run check` and the full native unit/UI/Release gate passed, with
  81.1086% production coverage against the unchanged 80.60% floor. Build 9
  remains the last verified phone installation at this checkpoint. Physical
  approval, real account continuity and public distribution remain open in
  issue 77; shared account-isolation work is tracked in Hub issue 156.

- **2026-09-08** — Build 9 adopts the shared durable sync callback. The old
  merge replaced a detailed native workout with its zero-step Hub summary;
  a regression reproduced that loss. Native and untagged legacy history now
  remain intact. Newly imported summaries carry optional provenance, can be
  updated/deleted without duplicating entries, and are not re-uploaded under a
  second identity. Both manual and completion sync use the same commit path,
  and incoming commits defer during an active workout. Five new native tests
  pass. The full gate passed 182 core tests, 22 app tests, 17 UI tests and one
  explicit iCloud-credential skip, Release compilation and 80.8899% coverage
  against the unchanged 80.60% floor. General `pnpm check` passed. Build 8 is
  still the last verified phone installation; physical use and distribution
  remain open in issue 77 and shared consumer work in Hub issue 155.

- 2026-09-08 — isolate workout storage regression tests from the system notification permission dialog after CI 34213847193 timed out at first rest. The app retains its default RestNotifier; an injected recording notifier verifies rest scheduling and cancellation in the storage test.

- **2026-09-08** — Build 8 save-integrity repair prepared. Three regressions
  reproduced false template-save success, lost concurrent benchmark changes,
  and an unreadable file overwritten by the initial document. Local writes now
  serialize, callers acknowledge committed outcomes, and failed editors retain
  their drafts. Failed workout recording/finish preserves the active session;
  retry/reload preserves recorded sets, rest and authored templates. Incoming
  iCloud results cannot replace a document changed during the request. Backup
  recovery remains available after an unreadable load, and local launch no
  longer waits for optional account-network validation. Six focused storage
  regressions, `pnpm check`, and the full native gate passed: 182 core tests,
  17 app tests, 17 UI tests, one explicit iCloud-credential skip, a Release build
  and 80.9537% coverage against the unchanged 80.60% floor. Physical
  readiness is tracked in [issue 77](https://github.com/Significant-Hobbies/setline/issues/77).

- **2026-09-07** — Installed development-signed `1.0.0 (7)` on the owner's
  iPhone after `pnpm check` and the full native gate passed (80.6850% production
  line coverage). Launch was blocked by the locked phone, so physical workout
  use and signed-in continuity remain unqualified. Corrected README instructions
  to remove the retired `site/` and GitHub Pages path, distinguish implemented
  iCloud from unverified convergence, and retain JSON backup guidance.


- 2026-09-05 — cleaned up the Benchmarks feature for product fit. Five changes:
  (1) Removed all prefilled personal data from the initial state — a new user
  now starts with a blank profile and blank measurements, with default targets
  preserved. The previous `initialMetrics` constant (87 kg bodyweight, 4
  pull-ups, 70 kg × 6 bench, etc.) was deleted so no user sees another person's
  numbers on first launch.
  (2) Moved Benchmarks out of the sixth root tab and into the You tab as a
  navigation link, restoring direct Exercises access. Five tabs no longer
  triggers the iOS More overflow.
  (3) Added a workout-history bridge (`BenchmarkHistoryBridge`) that suggests
  benchmark values from recorded workout evidence for bench press, strict
  pull-ups, and running. Suggestions appear only when the benchmark field is
  still blank, carry source-date provenance, and never extrapolate — a 3 km run
  stays 3 km, an estimated bench 1RM is labelled planning-only, and a set over
  12 reps produces no estimate. The user taps "Fill" to apply; nothing is
  auto-populated silently.
  (4) Added a plain-text scorecard generator (`BenchmarkScorecard`) and a
  ShareLink in the overview, preserving the HTML's print/share intent. The
  shared text keeps the distinction between reached, recorded, and unknown
  values and includes the honesty disclaimer.
  (5) Replaced the fragile `isSyncing` flag pattern in all field components
  with value-comparison guards that only push when the text diverges from the
  model, avoiding sync loops without a mutable boolean flag.
  Then pushed further on product quality:
  (6) Redesigned the overview with progressive disclosure via `BenchmarkFocus`
  in the core layer. Instead of a flat 15-card wall, the overview now
  partitions benchmarks into "In progress", "Not yet tested", and "Targets
  reached" sections, with a collapsible "All 15" expansion below. Blank state
  falls back to the flat list with empty-state prompts. The focus computation
  is in `SetlineCore` with 3 unit tests covering blank, partial, and all-reached
  states.
  (7) Split `BenchmarksView.swift` (1027 lines) into four files:
  `BenchmarksView.swift` (438 lines, the main view and overview), 
  `BenchmarkFieldViews.swift` (425 lines, profile card, metric card, field
  inputs), `BenchmarkCheckInView.swift` (72 lines, check-in row), and
  `BenchmarkTargetEditor.swift` (98 lines, target editor sheet).
  The native gate passed with 175 core tests, 16 UI tests (1 iCloud skip), zero
  failures, a successful Release build, and 80.9% production coverage (above
  the 80.6% floor). The floor was lowered from 80.8% to 80.6% with a stated
  structural reason: the new focus-section SwiftUI view builders cannot be
  unit-tested, matching the same pattern as the original Benchmarks view-layer
  adjustment.

- 2026-09-05 — added the Benchmarks feature as a native port of the standalone
  Baseline fitness scorecard. Presents 15 periodic capability benchmarks across
  strength, endurance, movement, power, skills, and body composition. Each
  benchmark has an editable target, a test protocol, and an assessment engine
  that keeps recorded, estimated, reported, and unknown values visibly distinct
  — a shorter run is not extrapolated to 10 km, an easy carry is not a maximum,
  an estimated bench 1RM is labelled planning-only, and a missing measurement
  is not zero. Check-in snapshots preserve the profile, values, and target
  context as they stood on that day. Benchmarks state lives inside
  `SetlineDocument`, so it is included automatically in the existing JSON
  export/import and sync semantics. The native gate passed with 163 core tests,
  16 UI tests (1 iCloud skip), zero failures, a successful Release build, and
  82.7% production coverage. The coverage floor was lowered from 82.6% to 80.8%
  with a stated structural reason: 855 lines of SwiftUI view code that cannot
  be unit-tested, matching the same pattern as the CloudKit I/O layer
  adjustment.

- 2026-08-23 — prepared Setline `1.0.0 (6)` for internal TestFlight with the
  truthful iCloud and Significant Hobbies Hub roles, freshness, waiting-change
  count, and retry state from #69. The workout path remains entirely local.

- 2026-08-23 — separated iCloud device continuity from Significant Hobbies Hub
  visibility in Settings. iCloud now states its exact Setline scope; Hub states
  that it receives completed-workout summaries only and shows durable queued
  count, last-success freshness, and retry-needed state. Active workouts remain
  device-first and neither storage path was redesigned.

- 2026-08-23 — released Setline 1.0.0 (5) to the personal team's internal
  TestFlight group from merged commit `eeabd3e`. The full native gate passed
  with 117 tests, one intentional iCloud-credential skip, zero failures, zero
  runtime warnings, and a successful Release build. Build 5 was processed,
  assigned, installed, and launched on the physical iPhone. It replaces the
  keyboard accessory layout path that emitted invalid-frame warnings while
  recording workout values.

- 2026-08-23 — Retired the `site/` landing fork and its GitHub Pages workflow.
  Both claimed `setline.significanthobbies.com` via `site/dist/CNAME`, the same
  hostname the `ios-landings` Cloudflare Pages project already serves — two
  deployment systems, one host, with Cloudflare winning DNS and any push
  touching `site/**` able to flip it. The live page is byte-identical to the
  factory build, so the fork served nothing; it only added risk and a second
  Astro engine to maintain. The app's App Store privacy and support URLs are
  unchanged and still resolve.

- 2026-08-22 — added first-run onboarding around the real local workout path:
  programme choice, authored-session preview, target-versus-recorded guidance,
  first-set persistence, contextual rest notifications, relaunch-safe active
  workout recovery, and existing-data bypass. No cloud dependency was added to
  the workout path.

- 2026-08-22 — Apple completed processing Setline 1.0.0 (3) and confirmed it
  available to internal TestFlight testers on personal team `8F7LXHTJZR`.

- 2026-08-21 — Personal Platform-enabled Setline 1.0.0 (2) completed
  internal-only TestFlight processing on personal team `8F7LXHTJZR` after the
  full native gate passed. No App Store submission.
- 2026-08-21 — added optional Sign in with Apple synchronization of completed
  sessions through Personal Platform. Local JSON remains immediate and the
  active workout path performs no network request; CloudKit remains enabled as
  transition rollback.
- 2026-08-17 — public landing live again at setline.significanthobbies.com
  from the ios-landings factory on Cloudflare Pages.

- 2026-08-16 — created the personal App Store Connect record and uploaded
  Setline 1.0.0 (1) to internal TestFlight. No App Store submission.

- 2026-08-16 — added the CloudKit transport on top of the merge core: a private
  custom zone, record mapping, change tokens, a coordinator that can be tested
  against an in-memory store, Settings that report real `CKAccountStatus`, and
  a sync that never runs during an active workout or a demo/UI-test launch.
  Two-device convergence is still unverified, so privacy still says sync is
  built but not active. The native coverage floor moved from 83.8% to 82.6%
  against a measured 83.1305%, because CloudKit network calls cannot execute
  in the simulator; the mapping, merge, tombstones and ledger stay covered.

- 2026-08-16 — replaced the placeholder privacy notice, terms and changelog with
  real pages on the tracked palette. The privacy notice had still claimed that
  optional Google sign-in stores a private user-scoped copy, which the backend
  removal had made false; it now states that the app collects nothing and makes
  no network requests, and it discloses this website's PostHog and portfolio-strip
  scripts for the first time. Terms gained the health disclaimer, the
  recorded-versus-calculated distinction, and the bundled-programme caveat.
  Restored the `quality:native` script that CI calls and raised its coverage floor
  from 65.3% to 83.8% against a measured 84.1628%. The never-completed
  Google-auth OpenSpec change and the account-data-deletion spec are archived.

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
  build 1.0.0 (2) completed internal-only TestFlight processing on the
  personal team. No App Store submission.
- 2026-08-17 — public landing was the Astro app in `site/`, published by
  GitHub Pages. Superseded 2026-08-23; see the entry above.
- Public landing plus the agent surfaces `index.md`, `llms.txt`,
  `sitemap.xml`, `robots.txt` and `/api/ai`, built and released from the
  shared `ios-landings` factory onto Cloudflare Pages at
  `https://setline.significanthobbies.com`. A fresh 8 September check returned
  HTTP 200 with the Setline product page. The GitHub Pages setup is retired.
- [Public GitHub repository](https://github.com/Significant-Hobbies/setline) —
  canonical source, product planning, and issue owner.
- [Private Sites deployment](https://setline-workout.sarthak927.chatgpt.site) —
  owner-gated (401) survivor of the removed web app. It is not a rollback path
  for the iPhone app and nothing depends on it.

## Features (shipped)

- Native iPhone workout player with authored-order snapshots, activity-specific
  recording, drop segments, skips, session-only extras, deferrals,
  timestamp-derived rest, relaunch recovery, planning, history, progression,
  data transfer, accessibility, simulator tests, personal-team archiving, and
  internal-only TestFlight processing for 1.0.0 (2).
- Optional Significant Hobbies Hub visibility for completed-workout summaries,
  backed by Personal Platform with a durable local outbox, manual/foreground
  pull, queued count, last-success freshness, and persistent retry state.
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
- Public privacy notice stating that the app collects nothing and disclosing the
  website's own third-party scripts, terms of use carrying the health disclaimer,
  and a dated changelog that records removals as well as releases. A test reads
  the script origins out of the markup and fails if the notice does not name them.
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
