## 1. Auth and Cloud State Foundation

- [x] 1.1 Run the dependency cleanup review and add exact Better Auth and Drizzle ORM versions.
- [x] 1.2 Add the D1 auth/state migration, Drizzle schema, and generated Worker binding types.
- [x] 1.3 Add per-request Better Auth configuration with Google, explicit trusted origins, and minimum scopes.
- [x] 1.4 Add bounded, authenticated, user-scoped state GET/PUT routes and health/config routes.

## 2. Client Account and Sync

- [x] 2.1 Upgrade local state to a versioned envelope with explicit modification time and backwards restoration.
- [x] 2.2 Add Google sign-in, device-only mode, session restoration, and sign-out.
- [x] 2.3 Add deterministic newer-envelope reconciliation and offline pending-write retry.
- [x] 2.4 Preserve one-tap set completion, rest timing, and authored exercise order in every account/sync state.

## 3. Product Surfaces

- [x] 3.1 Add the preserve-lane account-choice and compact account/sync status UI.
- [x] 3.2 Add public privacy and terms routes with accurate local, Google identity, D1, retention, and deletion copy.
- [x] 3.3 Update the service worker, README, product/design truth, and PROJECT_STATUS for auth and Cloudflare ownership.

## 4. Cloudflare and Google Configuration

- [x] 4.1 Add the tagged deploy command, Worker config, custom domain, D1 binding, assets, and observability.
- [x] 4.2 Register Setline in Fleet project and deployment configuration.
- [ ] 4.3 Create the production D1 database and apply the numbered migration.
- [ ] 4.4 Create the dedicated Google OAuth web client and set all Worker secrets without persisting secret values.

## 5. Validation and Release

- [x] 5.1 Run lint, typecheck, tests, build, strict OpenSpec validation, Worker dry run, and dependency/security checks.
- [ ] 5.2 Verify local, signed-out, signed-in, offline, sync-conflict, and ordered active-workout flows in a browser.
- [x] 5.3 Complete the preserve-lane responsive design review and pass its receipt.
- [ ] 5.4 Merge through green main, pass the Fleet deploy guard, deploy the SHA-tagged Worker, and smoke-test production OAuth and state isolation.
- [ ] 5.5 Archive the change and update the durable Setline and Fleet status surfaces.
