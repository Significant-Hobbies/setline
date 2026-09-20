---
title: "Combining strength, cardio, and mobility in one execution log"
slug: "combining-strength-cardio-and-mobility-in-one-execution-log"
target_query: "combining strength cardio mobility tracking"
search_intent: "Informational/Investigational - users looking for methods or tools to track different types of fitness training in one place without losing specific measurement details."
meta_title: "How to combine strength, cardio, and mobility in one execution log"
meta_description: "Learn how to execute and track strength, cardio, and mobility training within a single, structured workout log without losing modality-specific details."
---

## Outline

1. Introduction
2. The Challenge of Tracking Multimodal Training
3. Designing an Authored, Immutable Order
4. Tracking Strength: Loads, Repetitions, and RPE
5. Tracking Cardio: Duration, Distance, and Intervals
6. Tracking Mobility: Time, Repetitions, and Consistency
7. Maintaining Honest Measurements Across Modalities
8. Assessing Progress Through Periodic Benchmarks
9. Adapting on the Fly: When Plans Change
10. Internal Link Suggestions
11. Practical Next Action
12. Source Notes

## Introduction

Modern training programmes rarely focus on a single physical attribute. A well-rounded approach typically demands a combination of strength training to build force production, cardiovascular work to improve energy systems, and mobility practice to ensure movement quality and tissue health. However, executing a multimodal programme presents a specific challenge: how do you keep track of such different types of work in one continuous session without losing the precision required for each?

Many athletes rely on fragmented systems, using one app for running, a notebook for weightlifting, and memory for mobility work. This fragmentation breaks the flow of a training session. Setline, a mobile-first workout execution tracker, approaches this problem differently. By treating strength, cardio, and mobility as distinct modalities that can be sequenced into a single immutable order, Setline allows users to build their plan once and follow it precisely every day.

## The Challenge of Tracking Multimodal Training

When combining different physical disciplines, the immediate friction point is data structure. Strength training relies on discrete sets, repetitions, load, and rest periods. Cardiovascular training often relies on continuous duration, distance, pace, or structured interval rounds. Mobility training might involve static holds measured in seconds or dynamic movements measured in repetitions.

Trying to force cardio into a strength-tracking format, or vice versa, leads to compromised data. For example, logging a 5-kilometre run as "1 set of 5000 reps" is a hack that ruins historical analytics and makes progress difficult to read. Furthermore, when training involves all three modalities in a single session, the athlete needs an execution layer that fluidly transitions between these different data types without requiring them to switch contexts or make decisions between sets.

The core proposition is straightforward: the athlete already has a structured training programme. They do not need a digital coach to generate a workout; they need a precise execution log that keeps the planned order, targets, rest periods, and recorded results close at hand.

## Designing an Authored, Immutable Order

A fundamental principle of effective execution is maintaining the authored order of a session. A programme is written in a specific sequence for physiological reasons. The warm-up prepares the tissue, the primary strength movement demands the freshest central nervous system, and the conditioning work safely depletes remaining energy stores.

When tracking a session that combines strength, cardio, and mobility, the execution log must respect this exact sequence. In Setline, exercise and set order is treated as immutable programme data, not a suggestion. A session starts in the exact order it was authored. This means a user can structure a workout that transitions seamlessly from mobility preparation to working sets, and then directly into a cardio cooldown, with every step retaining its authored position during execution and in history.

This strict adherence to the authored sequence removes decision fatigue in the gym. Used primarily on a phone with mixed lighting, limited attention, and sweaty hands, the repeated action is simply completing a set and immediately entering a timed rest period. The athlete does not need to decide what to do next; they just follow the line.

## Tracking Strength: Loads, Repetitions, and RPE

Strength work demands precise recording of mechanical tension and volume. An execution log must handle not just straightforward sets, but also complex rep schemes.

For weight-and-repetition work, the log must support structured set targets carrying repetition ranges, load (which might be absolute weight, relative to bodyweight, or assisted), repetitions in reserve (RPE), tempo, and per-side work. Kilograms are typically the default unit for strength, but the system must be flexible.

Crucially, strength execution is rarely perfectly clean. A user might fail a set, drop the weight, or perform partial repetitions. To accurately reflect what happened, the log must allow for ordered partial or drop segments. For example, if a target is 60 kg for 8 repetitions, but the user only manages 5 repetitions before dropping to 50 kg for 3 more to finish the set, the log must record this exact sequence (`60 kg × 5` followed by `50 kg × 3`) within one completed planned set.

## Tracking Cardio: Duration, Distance, and Intervals

Cardiovascular training requires a different measurement approach. While strength focuses on load and repetitions, cardio focuses on duration, distance, rounds, and pace.

When integrated into a single execution log, cardio blocks must use their written duration or repetition dose rather than being forced into a strength template. An authored programme might include week-aware hard-cardio rounds or easy cardio cooldowns. The log must present these tasks clearly, allowing the user to record the actual time under tension or distance covered.

By treating cardio as a first-class citizen alongside strength, the athlete gains a complete picture of their training load.

## Tracking Mobility: Time, Repetitions, and Consistency

Mobility and flexibility work is often the most neglected aspect of a training programme, partly because it is notoriously difficult to track effectively. Integrating mobility directly into the execution log elevates its importance and ensures it is treated with the same respect as the other modalities.

These tasks might be measured in time (e.g., a two-minute passive stretch) or repetitions (e.g., ten controlled articular rotations per joint). By placing these directly in the immutable session sequence, the athlete is guided through them step-by-step. The one-tap completion action applies just as easily to finishing a static hold as it does to completing a heavy set of bench press.

## Maintaining Honest Measurements Across Modalities

A critical principle of a combined execution log is honest measurement. When dealing with multiple modalities, it is vital to keep recorded, calculated, authored, adjusted, and unavailable values visibly distinct.

If an athlete runs for a duration but does not know the exact distance, the system should not extrapolate an estimated distance based on an assumed pace. If a bench press one-rep max is estimated from a set of five repetitions, it must be explicitly labelled as a planning-only estimate. Missing history is never treated as missed training, and unavailable data is not silently replaced with zeroes or guesses.

This distinction is crucial for both strength and cardio. If a deterministic progression recommendation suggests a higher load for the next session based on previous performance, the user must explicitly Accept, Edit, or Keep the current input. The system never mutates the authored programme silently. The athlete retains total control over the plan, while the log accurately reflects reality.

## Assessing Progress Through Periodic Benchmarks

While daily execution tracking is about following the plan, periodic assessment is necessary to gauge the effectiveness of the multimodal programme.

A comprehensive log can include a Benchmarks scorecard, offering periodic capability checkpoints across different domains: strength, endurance, movement, power, skills, and body composition. This allows the athlete to track a 3-kilometre run, a strict pull-up max, and a resting heart rate in one unified view.

Each benchmark should have an editable target, a specific test protocol, and check-in snapshots that preserve the profile, values, and target context as they stood on that day.

## Adapting on the Fly: When Plans Change

Even the best-authored plans encounter reality. An athlete might find a piece of equipment occupied, run out of time for their cardio finisher, or need to skip a mobility drill due to a minor tweak.

An execution log must be adaptable without destroying the underlying structure. Explicit in-session changes must be allowed but remain distinct from the written programme. If a user needs to skip an exercise, add a session-only extra set, or move the current step to "Do later", the log must record this deviation accurately.

Crucially, these deviations never silently rewrite the programme or future workouts. A session starts in the exact authored order, and an immutable snapshot is taken. The history reflects the reality of what was executed—the skips, the drops, the additions—while the authored template remains pristine for the next time it is scheduled.

## Internal Link Suggestions

*   Link "mobile-first workout execution tracker" to the Setline product landing page.
*   Link "Benchmarks scorecard" to a detailed guide on tracking fitness capability checkpoints.
*   Link "deterministic progression recommendation" to an article explaining how session-only load recommendations are calculated and applied.
*   Link "authored, immutable order" to documentation on creating custom workout templates.

## Practical Next Action

To stop juggling different apps for different physical disciplines, build your combined strength, cardio, and mobility routine as a single, ordered template. Define the exact sequence of your warm-up, primary lifts, conditioning blocks, and cooldowns. Once the structure is set, rely on a dedicated execution log to guide you precisely through the session, focusing entirely on the effort of each set rather than managing the data.

## Source Notes

**Authority:**
*   `PRODUCT.md`: Confirms Setline is a "mobile-first workout execution tracker" where "exercise and set order is immutable programme data". Details support for strength, cardio, mobility, warm-ups, and cooldowns. Explicitly mentions partial/drop segments (e.g., `60 kg × 5` followed by `50 kg × 3`), honest measurement (keeping recorded, calculated, and unavailable values distinct), and deterministic progression recommendations requiring explicit user action. Confirms kilogran defaults for strength and duration/repetition for cardio and mobility.
*   `PROJECT_STATUS.md`: Confirms the Benchmarks scorecard features 15 checkpoints across strength, endurance, movement, power, skills, and body composition. Details the explicit recording of skips, session-only extra sets, and Do later deferrals. Confirms the implementation of a set timer independent of rest, and the separation of actual rest cadence from authored targets.

**Limitations:**
*   Setline does not generate programmes; it is an execution layer for user-authored plans.
*   It does not extrapolate data (e.g., missing measurements remain missing; estimated 1RMs are labeled planning-only).
*   No coaching, AI program generation, or social features are present in the current build.
*   All data handling described must be performed locally on-device during the workout, as active workouts do not depend on network requests.
