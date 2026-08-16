# Setline

Setline is an iPhone training tracker for following an authored programme,
recording actual sets, controlling rest, and measuring each exercise against a
target you set. It has no backend: everything runs and records on the device, and
the versioned JSON export is the only way data moves.

The iPhone app lives in [`ios/`](./ios). The public site is static files in
[`public/`](./public) published by GitHub Pages, and nothing the app does depends
on it. There is no backend and no hosting account to maintain.

Site: [setline.significanthobbies.com](https://setline.significanthobbies.com)

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
pnpm run check
```

The release includes the owner-authored 12-week programme, custom workout
templates, one bounded multi-week custom programme, flexible execution,
device-local continuity, versioned whole-state backup/restore, optional private
account sync, history, progress, and explicit deterministic session-only
progression recommendations. Multiple programme libraries, arbitrary workout
import, reminders, coaching, sensors, health integrations, social features,
and full analytics remain deferred.

Source, product planning, and work tracking live in this repository. Fleet
Workspace consumes only catalog and operational links.
