---
version: 1
slug: "app-page-tsx"
primary_target: "app/page.tsx"
related_targets: []
---

## Scope and mode

- Target: `app/page.tsx`
- Mode: Operate
- Scope: account choice, private sync status, programme overview, active workout, rest, summary, history, and progress states

## User and job

A lifter in the gym needs to follow Sarthak's dated 12-week programme in order,
record each strength, cardio, or mobility step with minimal interaction, and
trust the next target and rest deadline without consulting the PDF.

## Primary task

Open the calendar-correct session, complete or skip each authored step, adjust
rest when necessary, then save an honest modality-aware session record.

## Content and constraints

- Use the supplied 27 July–18 October 2026 programme and preserve every authored
  exercise and step position.
- Keep the active target, actual inputs, previous result, form cues, and completion control immediately visible.
- Distinguish recorded results from calculated volume.
- Preserve device-first operation, explain the device-only boundary, and make
  optional private account synchronization status explicit.
- Never let account restoration, conflict resolution, or retry reorder an
  exercise or set.
- Meet keyboard, touch, contrast, reduced-motion, and responsive requirements.

## Chosen direction

Scoreboard split, quieter pass: the current attempt remains dominant while a
fine-lined ordered session rail preserves context. Chalk and paper dominate;
lime is reserved for the Complete step slab, focus, and compact current-state
marks. The memorable moment remains the transition to the timestamp-derived
rest board with the completed-step receipt visible.

## Account and sync direction

Google sign-in is optional and uses a restrained account-choice board before the
workout shell. Device-only remains a first-class path. Signed-in state is a
private Setline copy in Cloudflare D1, authenticated through Google; the compact
header status reports account and synchronization truth without competing with
the current set.

## Unresolved decisions

General-purpose programme editing/import, reminder channels, and self-service cloud-data
deletion remain outside this surface.
