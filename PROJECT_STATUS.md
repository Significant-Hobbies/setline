# Setline Project Status

## Why / What

Setline helps people execute a structured workout programme precisely without referring to another document or deciding what to do between sets. The user controls the programme; Setline presents the current action, records explicit results, controls rest, and separates recorded values from calculations.

The first release is a mobile-first web/PWA workout player. It includes a sample four-day programme, device-local session execution, basic history, and progress. It excludes coaching, automatic programme generation, social features, meal/recovery tracking, sensors, Apple Health, and Apple Watch.

## Dependencies

- React, Next.js, and Vinext for the web application.
- Vite and the Cloudflare plugin for the Sites-compatible build.
- Browser `localStorage`, Service Worker, vibration, and installation APIs where supported.
- No account provider, database, email provider, paid service, secret, or Fleet runtime dependency.

## Timeline

- 2026-07-27 — Scoped and built the first Setline workout-player release from the supplied PRD.
- 2026-07-27 — Published version 1 as an owner-only Sites deployment.

## Products

- `foundry/apps/setline/` — installable mobile-first Setline web app.
- [Private Sites deployment](https://setline-workout.sarthak927.chatgpt.site) —
  owner-only hosted release.

## Features (shipped)

- Four-day sample programme overview with today's Upper A session.
- Guided warm-up and working-set execution.
- One-tap set completion with editable actual weight, repetitions, and optional RPE.
- Set skipping and ordered session rail.
- Timestamp-derived automatic rest timer with pause, add-time, and skip/start controls.
- Device-local active-session continuity and workout history.
- Honest summary with separate warm-up/working volume and calculated provenance.
- Basic sample exercise trend plus local recorded-volume signal.
- Responsive phone, tablet, and desktop layouts.
- PWA manifest, install metadata, service-worker shell, and offline-friendly local operation.

## Todo / Planned / Deferred / Blocked

### Planned

1. Add manual programme/workout authoring and duplication.
2. Add validated JSON import/export with preview.
3. Add accounts, cloud synchronization, queued offline writes, and data migration.
4. Add browser/email reminders.
5. Add deterministic progression recommendations with explicit accept/edit/keep actions.
6. Expand exercise, workout, and programme analytics from recorded history.

### Deferred

- Precise start/finish set mode until the one-tap simple mode is validated.
- CSV import, exercise library authoring, cardio/distance tracking, supersets, and circuits until the core player is retained.
- Replace the Vinext-compatible Next.js toolchain when upstream releases remove
  the remaining embedded PostCSS and Sharp advisories. This owner-only release
  does not accept arbitrary CSS or use Next image optimization, the affected
  runtime paths identified by the production audit.
- Native Apple Health, Apple Watch, heart rate, and sensor capture until the web product proves useful.
- Internal AI, automatic programme generation, extraction, form analysis, social, trainer, meal, and recovery features per the PRD.

### Blocked

- None for the device-local workout-player release.
