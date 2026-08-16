# Setline

Setline is an iPhone training tracker for following an authored programme,
recording actual sets, controlling rest, and measuring each exercise against a
target you set. It has no backend: everything runs and records on the device, and
the versioned JSON export is the only way data moves.

The iPhone app lives in [`ios/`](./ios). The public site is static files in
[`public/`](./public) published by GitHub Pages, and nothing the app does depends
on it. There is no backend and no hosting account to maintain.

Site: [setline.significanthobbies.com](https://setline.significanthobbies.com) —
dark until its DNS record points at GitHub Pages ([#43](https://github.com/Significant-Hobbies/setline/issues/43)).

## Local development

The app:

```bash
./ios/scripts/check.sh          # xcodegen, simulator tests, release build
```

The public site:

```bash
pnpm install
pnpm run check                  # static-surface contracts and code health
python3 -m http.server -d public 8080
```

## Checks

```bash
pnpm run check                  # static surfaces and code health
pnpm quality:native             # xcodegen, simulator tests, release build, coverage
```

The release includes the owner-authored dated 12-week programme, structured set
targets, a bundled four-pillar movement catalogue, per-exercise measured current
values against authored targets, multi-segment set recording with a shorthand
parser, a set timer alongside rest, custom workout templates, one bounded
multi-week custom programme, device-local continuity, versioned whole-state
backup/restore, history, progress, and deterministic session-only progression
recommendations.

Deferred: iCloud sync across devices, Apple Health, Apple Watch, CrossFit
session formats, range-of-motion assessments, on-device workout generation,
coaching, and social features. Until iCloud sync lands, training lives only on
the device that recorded it and the JSON export is the only backup.

Source, product planning, and work tracking live in this repository. Fleet
Workspace consumes only catalog and operational links.
