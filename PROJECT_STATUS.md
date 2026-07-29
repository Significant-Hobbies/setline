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
- Better Auth and Google OAuth for optional identity.
- Cloudflare Workers and D1 for authenticated, user-scoped state.
- Browser `localStorage`, Service Worker, vibration, and installation APIs where supported.
- No email provider, paid service, sensor, or native runtime dependency.

## Timeline

- 2026-07-27 — Scoped and built the first Setline workout-player release from the supplied PRD.
- 2026-07-27 — Published version 1 as an owner-only Sites deployment.
- 2026-07-27 — Added optional Google sign-in, private D1 synchronization,
  public legal surfaces, and a guarded Cloudflare Worker release path.
- 2026-07-28 — Loaded the supplied 12-week programme in authored exercise order
  and refined the visual system to reserve lime for active actions and status.
- 2026-07-28 — Released flexible session execution with partial/drop segments,
  extra and deferred sets, actual rest cadence, and detailed history.

## Products

- `foundry/apps/setline/` — installable mobile-first Setline web app.
- `https://setline.significanthobbies.com` — live Cloudflare Worker production
  surface.
- [Private Sites deployment](https://setline-workout.sarthak927.chatgpt.site) —
  owner-only rollback copy.

## Features (shipped)

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
- Optional Google sign-in with one private, user-scoped D1 state copy.
- Device-first changes with offline retry and deterministic whole-state
  reconciliation.
- Explicit state validation that preserves authored exercise and set order.
- Public privacy notice and terms of use.
- Honest summary with separate warm-up/working volume and calculated provenance.
- Basic bench target context plus local recorded-volume signal.
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

## Work queue

Open work is tracked only in [GitHub Issues](https://github.com/sass-maker/fleet-workspace/issues?q=is%3Aissue+is%3Aopen+label%3A%22product%3Asetline%22).
An open issue is a to-do, a linked pull request is in progress, and merge plus
issue closure makes the work done.
