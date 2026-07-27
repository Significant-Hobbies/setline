# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Users

People who already have a structured training programme and need to execute it precisely in a gym without referring to another document or making decisions between sets.

## Product Purpose

Setline is a mobile-first workout execution tracker. The user defines the programme; Setline keeps the planned order, targets, rest periods, and recorded results close at hand. Success means a user can complete repeated weeks of training with accurate set history and minimal interaction during each session.

## Positioning

Setline is an execution layer for user-authored programmes, not a coach or automatic programme generator: build the plan once, then follow it precisely every day.

## Operating Context

- Used primarily on a phone in a gym with mixed lighting, limited attention, sweaty hands, and unreliable connectivity.
- The repeated action is completing a set and immediately entering a timed rest period.
- Workout content includes mobility, warm-ups, working sets, cardio, rest, form cues, and explicit progression rules.
- Recorded measurements must remain distinguishable from app-derived calculations and sensor-unavailable data.

## Capabilities and Constraints

- This release includes Sarthak's dated 12-week strength, cardio, and mobility
  programme, a seven-day weekly overview, guided workout execution, activity-
  appropriate recording, timestamp-derived rest timing, local workout history,
  and basic progress.
- Active workout actions must not depend on a network request.
- Exercise and set order is programme data, not a suggestion. The player follows
  the saved sequence exactly; the user may explicitly skip the current set, but
  Setline never silently jumps ahead or reorders the session.
- Workout actions are device-first and remain usable offline. Optional Google sign-in
  synchronizes one private whole-state copy without merging or reordering sets.
- Reminders, general-purpose authoring/import/export, full analytics, accepted
  progression recommendations, internal AI, Health integrations, sensors,
  social features, and coaching remain deferred.
- Kilograms are the strength programme's default unit; cardio and mobility use
  their written duration or repetition dose.

## Brand Commitments

- Product name: Setline.
- Voice: direct, precise, calm, and factual; never motivational, shaming, or coach-like.
- Core proposition: “Build the plan once. Follow it precisely every day.”
- The owner delegated visual direction for this release.

## Evidence on Hand

- The owner supplied a complete product requirements document covering programme creation, workout execution, rest timing, progression, scheduling, exercise tracking, analytics, import, offline behavior, data model, and success criteria.
- The owner supplied `Sarthak_12_Week_Strength_Cardio_Mobility_Plan.pdf`,
  covering 27 July–18 October 2026 with exact exercise order, warm-ups, cardio,
  mobility, and block rules.
- No customer testimonials, performance benchmarks, sensor data, or commercial claims are available and none may be fabricated.
- The initial sample has been replaced by the owner's authored programme.

## Product Principles

- User-controlled: recommendations never silently change a programme.
- Fast during workouts: completing a set is the dominant one-tap action.
- Structured: exercises, sets, timers, and rules are explicit data.
- Ordered: every exercise and set retains its authored position during execution and history.
- Honest measurement: recorded, calculated, and unavailable values stay distinct.
- Offline-friendly: an active workout remains functional without connectivity.

## Accessibility & Inclusion

The web app must support keyboard operation, visible focus, reduced motion, high contrast, large touch targets, and layouts that remain usable at common phone, tablet, and desktop widths.
