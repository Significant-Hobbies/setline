---
title: Recorded vs Calculated vs Unavailable Workout Values
slug: recorded-vs-calculated-vs-unavailable-workout-values
target_query: workout tracking data accuracy
search_intent: Understand the difference between measured training execution, software-derived estimates, and missing data, and why this distinction is critical for long-term programme progression.
meta_title: Recorded vs Calculated vs Unavailable Workout Values | Setline
meta_description: Learn why distinguishing exact recorded sets from calculated estimates and unavailable data is essential for accurate, structured workout execution.
---

## Outline

1. **The Core Problem with Training Data:** How workout software often conflates what happened with what it guesses happened.
2. **Recorded Values (The Ground Truth):** Defining objective facts from the gym floor—exact sets, partial drops, and actual rest periods.
3. **Calculated Values (The Derived Context):** The role and limits of derived numbers like estimated one-rep maxes and session-only recommendations.
4. **Unavailable Values (The Reality of Missing Data):** Why an untested benchmark or skipped set must remain a deliberate blank, not zero.
5. **Setline's Approach to Honest Measurement:** Preserving the authored plan while tracking reality without hidden mutations.
6. **Next Action:** How to audit your own training records today.
7. **Internal Links:** Suggested contextual routing.
8. **Source Notes:** Evidence files and claims limitations.

## The Core Problem with Training Data

Executing a structured training programme requires absolute clarity about what happened during each session. However, the software layer mediating modern fitness often compromises this clarity. In the drive to present perfectly complete charts and motivated progression curves, applications routinely blur the boundary between three fundamentally different types of information: recorded values, calculated values, and unavailable values.

When a workout application silently fills in a blank measurement with an average, scales a short run into an extrapolated long-distance pace, or quietly adjusts an authored training plan based on an algorithm's derived recommendation, the integrity of the user's data is lost. The historical record transforms from an objective log of physical work into a smoothed-over approximation.

For people who build or follow deliberate programming, this distortion is catastrophic. A programme is not a loose suggestion; it is a specific set of stimuli designed to produce a specific adaptation. If you cannot reliably distinguish between what you actually lifted, what a formula estimated you could lift, and what you simply did not test, you cannot make informed decisions about your next training block. Honest measurement demands that these three categories remain strictly and visibly distinct.

## Recorded Values: The Immutable Ground Truth

Recorded values are the objective facts of a training session. They represent the physical reality of the execution layer. When you perform a set, the recorded value is exactly the weight moved and the repetitions completed. It does not contain assumptions about form, fatigue, or hypothetical performance under different conditions.

Consider a weight-and-repetition working set. If an authored programme dictates five repetitions at 60 kilograms, and the user executes exactly that, the recorded value is `60 kg × 5`. However, reality in the gym is rarely that uniform. A user might experience mid-set failure or deliberately employ a drop set technique. The recorded value must accurately reflect this complexity without artificially rounding up or simplifying the work. For instance, a recorded execution of `60 kg × 5` immediately followed by `50 kg × 3` as a drop segment within the single planned set is an exact reflection of the session. It tells a specific story about capability and fatigue on that specific day.

Rest periods are another critical domain of recorded values. An authored programme might stipulate a rigid three-minute rest between heavy sets. The timer setting is a target, but the actual gap between the completion of one set and the start of the next is the recorded reality. If a user manually adjusts the timer, or if they simply wait four minutes before starting the next set, the recorded history must retain the authored target, the timer adjustment, and the actual completion-to-next-start gap as completely separate data points.

Recorded values are the only true currency of physical progression. They must remain untouched by algorithms, never silently overwritten to make a graph look cleaner.

## Calculated Values: The Derived Context

Calculated values are derived from recorded facts using mathematical models or logical rules. They provide context, pacing, and planning assistance, but they are intrinsically different from recorded values. They are interpretations of reality, not reality itself.

A common example is the estimated one-repetition maximum (1RM). If a user records a top set of `100 kg × 5`, a formula might calculate an estimated 1RM of `112.5 kg`. This calculation is useful for planning a future block of heavy singles, but it is entirely distinct from a recorded 1RM. If a user has not actually placed 112.5 kg on their back and squatted it, claiming they have done so in their history pollutes their data. In a rigorous system, such an estimated 1RM is explicitly labelled with "calculated provenance" or marked as "planning-only." It is visual context, not a recorded physical achievement.

Similarly, progression recommendations are calculated values. An application might examine the latest comparable recorded workout and use deterministic rules to suggest a load for today's session. The recommendation is a calculated intervention. Crucially, a calculated recommendation must never silently mutate the authored programme. The user must make an explicit choice to Accept, Edit, or Keep the current input. The application acts as a calculator presenting an option; the user remains the author of the action.

## Unavailable Values: The Reality of Missing Data

The most difficult category for software to handle gracefully is the unavailable value. This is data that was not measured, tests that were not performed, or sets that were skipped or deferred.

In a system tracking a broad spectrum of physical capabilities—such as a scorecard measuring strength, endurance, movement, power, skills, and body composition—it is guaranteed that a user will not test every parameter every week. A new user might start with a blank profile. They may know their bench press but not their 3 km run time.

When a measurement is missing, the mathematically correct representation is null, not zero. If a benchmark is untested, it remains a deliberate blank. A missing measurement does not mean the capability is absent; it means the data is absent.

Furthermore, an unavailable value cannot be synthesized from a distinct recorded value. A shorter run is not extrapolated to a 10 km time. An easy farmer's carry is not scaled into a maximum carry capacity. If a set in a workout is explicitly moved to "Do later" or skipped entirely, the execution record must explicitly show that deviation.

Filling in unavailable data with guesses builds a house of cards. When a user reviews their check-in snapshots months later, they must be certain that the values present are exactly what was recorded, and that the blanks represent true unknowns.

## Setline's Approach to Honest Measurement

Setline is designed exclusively as an execution layer for user-authored programmes. It does not function as an automated coach, nor does it generate programmes or silently adapt targets. Its architecture is built around preserving the precise distinction between what is planned, what is performed, what is calculated, and what is missing.

When a user defines a programme in Setline, that exercise and set order is treated as immutable programme data. It is not a suggestion. As a session begins, it starts in that exact authored order. During execution, users can explicitly skip an exercise, add a session-only extra set, or defer a step to "Do later." Setline records this deviation explicitly in the session's history without ever rewriting the underlying programme or altering future scheduled workouts.

For complex executions, Setline's recording model handles granular realities. Weight-and-repetition work accommodates ordered partial or drop segments—recording `60 kg × 5` followed seamlessly by `50 kg × 3` within a single planned set. Rest cadence tracking explicitly preserves the authored target, any timer adjustment made during the session, and the actual completion-to-next-start gap as distinctly separate values.

Calculations in Setline are strictly isolated. Deterministic session-only load recommendations are generated from the latest comparable recorded workout, but they require the user to explicitly Accept, Edit, or Keep the current input. The application never mutates the authored template. In the Benchmarks scorecard, check-in snapshots preserve the exact state of recorded, estimated, reported, and unknown values as they stood on that day. An estimated bench 1RM is visibly labelled as planning-only. A missing measurement remains deliberately blank. Setline enforces honest measurement by refusing to auto-populate blanks or extrapolate partial data.

## Next Action

Audit your current training log. Pick your most recent major workout and ask three questions: First, does the record explicitly show the difference between your target sets and what actually happened, including exact drop sets and rest deviations? Second, are your estimated one-rep maxes clearly visually separated from your actual tested lifts? Third, does your history preserve missing days and skipped exercises as deliberate blanks, rather than silently adjusting your future schedule? If your current method blurs these lines, it is time to shift to an execution system that treats your training data as objective evidence.

## Suggested Internal Links

*   **Building a Custom Programme:** Learn how to define immutable workout templates and set up a Monday-based 1-16 week block.
*   **Understanding Benchmarks:** Read the overview of the 15 periodic capability checkpoints and how to interpret planning-only estimates.
*   **Session-Only Modifications:** Review instructions on how to use skips, Do later deferrals, and extra sets without altering the authored plan.
*   **Exporting Your History:** Get details on generating a versioned local JSON backup of your raw execution data.

---

## Source Notes (Review Only / Do Not Publish)

**Repository Evidence Used:**

*   `PRODUCT.md`:
    *   **Positioning:** Setline is an execution layer.
    *   **Immutability:** Exercise/set order is immutable.
    *   **Data Distinction:** "Honest measurement: recorded, calculated, and unavailable values stay distinct."
    *   **Set Recording Details:** Drop segments: `60 kg × 5` followed by `50 kg × 3`.
    *   **Rest Cadence:** Retaining authored target, timer adjustment, and completion-to-next-start gap.
    *   **Recommendations:** Deterministic session-only load recommendations require explicit Accept, Edit, or Keep actions.
*   `PROJECT_STATUS.md`:
    *   **Benchmarks Feature:** 15 capability checkpoints preserve recorded, estimated, reported, and unknown values.
    *   **Extrapolation Rules:** Shorter run not extrapolated to 10 km, easy carry not a max, estimated bench 1RM is planning-only, missing measurement is not zero.
    *   **Analytics Integrity:** "Honest summary with separate warm-up/working volume and calculated provenance."
*   `AGENTS.md`:
    *   "Keep recorded, calculated, authored, adjusted, and unavailable values visibly distinct."

**Important Limitations:**

*   No claims of App Store availability, commercial success, or specific sensor integrations.
*   No capabilities outside of documented JSON export, local history, and bounded custom programmes were invented.
*   Distinction between data types based solely on product's actual UI and data model constraints.
*   No specific SEO keyword volume or ranking difficulty referenced.