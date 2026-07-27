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

A lifter in the gym needs to follow a predefined session in order, record a set in one tap, and trust the next target and rest deadline without consulting another document.

## Primary task

Start Upper A, complete or skip each planned set, adjust rest when necessary, then save an honest session record.

## Content and constraints

- Use the approved sample programme and clearly label it as sample data.
- Keep the active target, actual inputs, previous result, form cues, and completion control immediately visible.
- Distinguish recorded results from calculated volume.
- Preserve device-first operation, explain the device-only boundary, and make
  optional private account synchronization status explicit.
- Never let account restoration, conflict resolution, or retry reorder an
  exercise or set.
- Meet keyboard, touch, contrast, reduced-motion, and responsive requirements.

## Chosen direction

Scoreboard split: the current attempt is oversized and dominant while an ordered session rail preserves context. The memorable moment is the transition from a lime Complete set slab to a large timestamp-derived rest board with the completed-set receipt still visible.

## Account and sync direction

Google sign-in is optional and uses a restrained account-choice board before the
workout shell. Device-only remains a first-class path. Signed-in state is a
private Setline copy in Cloudflare D1, authenticated through Google; the compact
header status reports account and synchronization truth without competing with
the current set.

## Unresolved decisions

Programme editing/import, reminder channels, and self-service cloud-data
deletion remain outside this surface.
