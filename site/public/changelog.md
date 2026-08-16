# Setline changelog

What shipped, newest first — including what was taken back out. Setline is
pre-release, so there are no version numbers yet.

## 16 August 2026 — Apple-only, and no backend at all

The Cloudflare Worker, its D1 database, and the whole account layer are gone:
Google sign-in, Sign in with Apple, private server-side state, and the
sync-conflict flow. Every table in that database held zero rows, so nothing was
lost — nobody had ever signed in. The web app went with it.

Setline is now one iPhone app with no server, no account and no hosting account,
and this site is static files. Training lives on the device that recorded it, and
the JSON export is the only way to move or back it up. Syncing across devices
through iCloud is the next thing being built.

## 16 August 2026 — Set targets that can express a real programme

Planned sets used to carry a line of free text, which meant a programme with rep
ranges, percentages, reps in reserve, tempo, per-side work and rest bands could
not actually be represented. Targets are now structured, and warm-up sets are
excluded from volume, records and progression rather than quietly counted.

The author's dated twelve-week strength, cardio and mobility block now resolves
natively for each of its 84 days, including week-dependent volume, the cardio
interval build, and the pull-up checkpoints. Progression follows the increments
the plan itself specifies.

## 16 August 2026 — Current, ideal, and the distance between them

Every exercise now has an identity, a measured current value, and a target you
author. Current values — estimated one-rep max, top set, max reps, best hold,
longest distance, best pace, range of motion — are derived only from completed
working sets, and each one cites the session that produced it. Progress shows the
gap, the weekly rate, a projected arrival date and a trend chart. With no
evidence there is no chart, rather than an invented one.

A bundled movement catalogue covers strength, stamina, mobility and flexibility,
plus the CrossFit movement vocabulary.

## 16 August 2026 — One set, recorded the way it happened

A set can now hold as many segments as it took: **5 reps × 40 kg** then
**2 reps × 30 kg** records as one set, not two. Shorthand entry accepts `5x40`,
`bw+10 x 8`, `assist 15kg x 6`, `45s` and `5km 25min`, and shows its
interpretation before anything is recorded — the parser is rule-based, so entry is
never a guess.

A set timer now runs alongside the rest timer, and a local notification fires
when rest ends so the timer survives leaving the app.

## 12 August 2026 — First native iPhone build

Complete workout execution on device: authored-order session snapshots,
activity-specific recording, skips, session-only extra sets, deferrals,
timestamp-derived rest, and recovery after relaunch. Plus planning, history,
versioned export and import, and accessibility work.

## 31 July 2026 — Progress from recorded history, and nothing else

Static example charts were replaced with analytics computed from real recorded
sessions, with bounded trends, explicit provenance for every value, and honest
empty states. Missing history is never treated as a missed workout.

## 28 July 2026 — Sessions that survive contact with a real workout

Partial and drop segments, extra sets, explicit deferral, and actual rest
cadence — recorded as deviations from the plan rather than edits to it. The
authored programme stays immutable; execution is a separate record.

## 27 July 2026 — First release

The workout player: one authored programme, presented one action at a time, with
explicit recording and controlled rest.
