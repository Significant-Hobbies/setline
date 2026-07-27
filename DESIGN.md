# Setline Design System

## Direction

Setline is a daylight strength-training scorecard: the legibility of an interval
timer, the notation of a training journal, and the command hierarchy of a
competition attempt board. Its quieter second pass keeps the instrument-like
structure while letting neutral paper, spacing, and authored workout content
carry the page. Lime is an execution signal, not the atmosphere.

The first release uses three structural probes within this world:

1. **Scoreboard split** — current set dominates while the remaining workout reads as a narrow attempt list.
2. **Timer tunnel** — elapsed/rest time dominates and the exercise plan becomes a sequence beneath it.
3. **Training strip** — the full session is a horizontal/vertical strip with one enlarged active set.

The delegated selection is **Scoreboard split** because it keeps target, actuals, and the one-tap completion action visible together on a phone while retaining enough context to reduce uncertainty.

## Physical Scene

A user checks Setline between sets under bright overhead gym lights, sometimes one-handed and out of breath. The surface is light, matte, and high-contrast; important numerals are readable at arm's length. Dark mode is not the default because this is not a bedroom or cinema interface.

## Palette

- `chalk`: `#f7f6f0` — primary field.
- `paper`: `#ffffff` — raised data surface.
- `ink`: `#18262e` — primary type and structural lines.
- `steel`: `#dde1dc` — dividers, inactive tracks, and quiet surfaces.
- `lime`: `#b9e83f` — primary action and compact active signal.
- `coral`: `#ff614d` — pain, destructive, over-target, and urgent state only.
- `blue`: `#b9d8e8` — recorded/history evidence and informational state.

Color never carries status alone. Every state has text, position, or shape support.

## Typography

- UI copy uses the local system sans stack for speed and dependable rendering.
- Targets, timers, weights, reps, and scores use a condensed system stack with tabular numerals.
- Labels are short uppercase phrases with moderate tracking; body copy is sentence case.
- Numerals carry the hierarchy. No display serif, motivational italic, or decorative script.

## Composition

- On phones, the current action owns the viewport: session line, exercise identity, set target, actuals, and primary completion control.
- Bottom navigation stays reachable but never competes with the current action.
- On larger screens, the current action occupies the left two-thirds and the remaining-session rail occupies the right third.
- Dense information is grouped by fine rules, alignment, and whitespace rather
  than heavy frames or nested cards.
- Corners are square or lightly clipped; generic rounded capsules are prohibited except for compact status tags whose shape communicates grouping.

## Components

- **Session bar:** compact workout title, progress fraction, elapsed time, and close/return control.
- **Attempt board:** exercise, set type, oversized weight × reps target, previous result, and form cues.
- **Actuals row:** large numeric inputs with explicit units and step controls that remain touch-friendly.
- **Action slab:** the one full-width lime completion control, with a restrained
  dark offset edge and direct verb.
- **Rest board:** oversized timestamp-derived countdown, completed-set receipt, next target, and inline adjustment controls.
- **Set rail:** explicitly locked ordered rows with preparation, warm-up,
  working, cardio, mobility, and cooldown labels and
  complete, active, upcoming, or skipped states. The rail communicates that
  sequence is part of the programme, not a sortable suggestion during execution.
- **Metric strip:** aligned label/value pairs with recorded or calculated provenance.

## Interaction

- Completing a set is the dominant single action.
- Rest begins automatically and remains anchored to an end timestamp.
- Motion is limited to a progress sweep, numeric countdown change, and short state confirmation. Reduced-motion users receive immediate state changes.
- Focus rings use a two-layer ink/lime treatment and never rely on browser defaults alone.
- Touch targets are at least 44 pixels.
- Destructive or irreversible actions require a secondary confirmation; skipping a set is reversible until session save.

## Responsive Rules

- `390px`: one-column current-action layout, sticky action/navigation zones, no horizontal scrolling.
- `768px`: two-column supporting data where it reduces vertical travel; primary action remains prominent.
- `1440px`: centered operational shell with fixed session rail and generous negative space, not an inflated phone mockup.

## Content and Measurement

- Programme targets are identified as authored plan data.
- User-entered values use “Recorded.”
- App math uses “Calculated.”
- Unsupported sensor information is omitted or labeled unavailable; it is never estimated.
- Warm-up and working volume remain separate everywhere.

## Intentional Exceptions

- The supplied 12-week programme is shipped as owner-authored product data; it
  is not represented as a general PDF import capability.
- Device-first persistence remains visible in settings and workout copy. Signed-in
  users receive a private account copy; device-only users receive no cloud claim.
