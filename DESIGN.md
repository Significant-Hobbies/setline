# Setline Design System

## Direction

Setline is a dark strength-training scorecard: the legibility of an interval
timer, the notation of a training journal, and the command hierarchy of a
competition attempt board. Its quieter second pass keeps the instrument-like
structure while letting matte dark surfaces, spacing, and authored workout content
carry the page. Lime is an execution signal, not the atmosphere.

The first release uses three structural probes within this world:

1. **Scoreboard split** — current set dominates while the remaining workout reads as a narrow attempt list.
2. **Timer tunnel** — elapsed/rest time dominates and the exercise plan becomes a sequence beneath it.
3. **Training strip** — the full session is a horizontal/vertical strip with one enlarged active set.

The delegated selection is **Scoreboard split** because it keeps target, actuals, and the one-tap completion action visible together on a phone while retaining enough context to reduce uncertainty.

## Physical Scene

A user checks Setline between sets under bright overhead gym lights, sometimes
one-handed and out of breath. The surface is dark, matte, and high-contrast;
important numerals remain readable at arm's length.

Owner decision (Phase C): **DARK EVERYWHERE**. Dark is the default and first-run
appearance, forced throughout the native app regardless of the device setting.
This overrides the previous guidance that dark mode was not the default. The
public landing must use these exact app tokens; its source remains ios-landings.

## Palette

- `background`: `#0f181d` — primary matte field.
- `foreground` / `chalk` / `onSurface`: `#f7f6f0` — primary text on dark surfaces.
- `card` / `paper`: `#18262e` — raised data surface.
- `surface`: `#1f2f38` — rest board, rail, and supporting surfaces.
- `muted` / `steel`: `#2a373e` — inactive tracks and quiet fills.
- `mutedForeground`: `#b1b3b1` — supporting text.
- `border`: `#2f373b` — dividers and card rules.
- `brand` / `lime`: `#b9e83f` — actions and compact active/status signals only.
- `brandForeground` / `ink` / `onLime`: `#18262e` — text on lime actions.
- `destructive` / `coral`: `#ff614d` — pain, destructive, over-target, urgent state.
- `blue`: `#b9d8e8` — recorded/history evidence and informational state.
- `caution`: `#f5d98c` — the existing benchmark caution badge, with ink text.

Text and rules formerly drawn with translucent ink now use chalk-based roles.
Small secondary text uses at least 62% chalk; informational blue washes use 12%
blue so chalk remains legible. Solid blue and coral controls use ink text.
Summary tiles use dark fills; lime is not a large decorative field. Native
forms and lists share the field/card tokens, and system controls use dark mode.

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
- **Actuals row:** large numeric inputs with explicit units and step controls
  that remain touch-friendly. Weight-and-repetition sets may expand into
  ordered segments without creating a separate advanced mode.
- **Action slab:** the one full-width lime completion control, with a restrained
  dark offset edge and direct verb.
- **Rest board:** oversized timestamp-derived countdown, completed-set receipt, next target, and inline adjustment controls.
- **Set rail:** programme-positioned rows with preparation, warm-up, working,
  cardio, mobility, and cooldown labels plus complete, active, upcoming,
  modified, extra, deferred, and skipped states. It shows the current session
  queue while retaining authored position, so an explicit deviation never
  looks like a rewritten plan.
- **Execution ledger:** a dense planned-versus-actual record showing every
  segment, planned and performed position, status, and available authored,
  adjusted, and actual rest.
- **Metric strip:** aligned label/value pairs with recorded or calculated provenance.

## Interaction

- Completing a set is the dominant single action.
- Add another set and Do later are quieter session-only actions; neither changes
  a future workout.
- Rest begins automatically and remains anchored to an end timestamp.
- Starting the next step records actual rest from wall-clock timestamps whether
  the user starts early or waits after zero.
- Motion is limited to a progress sweep, numeric countdown change, and short state confirmation. Reduced-motion users receive immediate state changes.
- Focus rings use a two-layer chalk/lime treatment and never rely on browser defaults alone.
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
