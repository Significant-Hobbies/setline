## Why

Setline is currently hosted behind a ChatGPT Sites owner gate, so it is not a
normal Fleet product and cannot offer user accounts or cross-device continuity.
The owner asked for the proven Calorie pattern: Cloudflare hosting, optional
Google authentication, and private per-user D1 persistence without weakening
the offline workout flow.

## What Changes

- Move the primary Setline production surface to one Cloudflare Worker at
  `setline.significanthobbies.com`.
- Add optional Google sign-in through Better Auth using only basic identity
  scopes.
- Keep a no-account device-only mode so an active workout remains usable
  offline.
- Add a private authenticated state API and D1 record so signed-in programme,
  active-session, and history state can resume across devices.
- Queue authenticated state changes locally while offline and reconcile them
  deterministically when connectivity returns.
- Add public privacy and terms surfaces required for the OAuth consent flow.
- Register the Worker, domain, auth model, and deployment ownership in Fleet.

## Capabilities

### New Capabilities

- `setline-private-account`: Optional Google authentication, private D1 state,
  legal surfaces, session controls, and production OAuth behavior.

### Modified Capabilities

- `setline-workout-player`: Extend device-local continuity to an optional
  authenticated sync mode while preserving authored exercise/set order and
  offline completion.

## Impact

- Setline client state, header, account entry, legal routes, service worker,
  tests, project documentation, and deployment scripts.
- Setline Worker entrypoint, generated Cloudflare binding types, one D1
  migration, and authenticated state endpoints.
- Exact production dependencies on Better Auth and Drizzle ORM; no additional
  UI framework or client state library.
- Cloudflare Worker, D1 database, Worker secrets, custom domain, and a dedicated
  Google OAuth web client.
- Fleet project/deployment registry entries and manual tagged deployment.
