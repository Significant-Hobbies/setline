# Withdrawn 2026-08-16

This change was never completed and has been withdrawn rather than archived as
delivered. Its premise no longer holds.

It proposed a Cloudflare Worker at `setline.significanthobbies.com`, optional
Google sign-in through Better Auth, and private per-user D1 state. All three
were built and then removed:

- The Worker and the `setline` D1 database were deleted on 2026-08-16. Every
  table held zero rows — no one ever signed in, so the cross-device continuity
  this change existed to provide was never once used.
- Better Auth, Google sign-in, Sign in with Apple, the private state API and the
  whole-document sync/conflict flow were removed with the backend.
- Setline is now Apple-only and device-first. `AGENTS.md` records the standing
  constraint: no backend, no Cloudflare, no database, no hosting account.

Cross-device continuity is still wanted. It is being pursued through iCloud
instead, which needs no server and no account of Setline's own. That is separate
work with its own proposal; nothing here should be revived to deliver it.

The proposal, design, tasks and specs are kept verbatim for the reasoning
record — particularly the offline-queue and deterministic-reconciliation design,
which stays relevant to any sync approach.
