# Setline

Follow your training plan. Record the truth.

An iPhone app that runs a written strength, cardio and mobility programme one set
at a time, records what was actually lifted, and shows how far each exercise is
from an authored target.

Status: in development. Not on the App Store yet. Free. iPhone only.

## What it does

- Resolves a dated programme day by day, including week-dependent rules such as
  added sets, interval round counts and scheduled reassessments
- Structured set targets: rep ranges, absolute, relative, bodyweight or assisted
  load, reps in reserve, RPE, tempo, per-side work, and rest as a band
- Excludes warm-up, preparation and cooldown work from volume, records and
  progression decisions
- Records one set as several segments, so 5 reps x 40 kg followed by
  2 reps x 30 kg stays a single set
- Times the set itself, separately from rest; rest is anchored to a wall-clock end
  time and notifies on completion
- Measures a current value per exercise (estimated 1RM, top set load, max
  repetitions, best hold, longest distance, best pace, range of motion) against an
  authored target, with rate of change and projected arrival
- Cites the session behind every measured value
- Applies double progression using the programme's own load increments
- Carries a bundled movement library across strength, stamina, mobility and
  flexibility, plus the CrossFit movement vocabulary
- Exports and imports all local data as versioned JSON

## What it refuses to do

- Invent, estimate or interpolate a value it has not recorded
- Draw a trend from fewer than two comparable sessions
- Rewrite an authored plan when a session deviates; deviations are recorded as
  deviations and authored positions are kept
- Require an account or a network connection to run a workout

## Not yet built

Syncing across devices through iCloud, Apple Health heart-rate zones and VO2
max, an Apple Watch app, AMRAP, EMOM and For Time scoring, range-of-motion
assessments, and on-device workout generation. These are not claimed as shipped.
Until iCloud sync lands, training lives only on the device that recorded it and
the JSON export is the only backup.

## Agent entrypoints

- https://setline.significanthobbies.com/llms.txt
- https://setline.significanthobbies.com/api/ai
- https://setline.significanthobbies.com/index.md
