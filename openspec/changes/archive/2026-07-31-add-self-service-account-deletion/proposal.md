## Why

Signed-in Setline users can leave the service but cannot currently remove their
Google-linked Setline account or private cloud workout copy themselves. The
existing D1 ownership model already supports complete cascading deletion, so
Setline can close that privacy and account-lifecycle gap without a migration or
new infrastructure.

## What Changes

- Enable Better Auth's authenticated user-deletion endpoint.
- Add a compact signed-in account-management action with explicit,
  irreversible confirmation.
- Delete the current user's auth records and private workout state through the
  existing D1 foreign-key cascades.
- Clear the deleted account's bound browser workout copy and auth/sync markers
  only after the server confirms deletion.
- Keep local state intact and explain the failure when deletion cannot be
  confirmed.
- Update the public privacy notice to describe self-service deletion.

## Capabilities

### New Capabilities

- `account-data-deletion`: Authenticated self-service account and private
  cloud-data deletion, including confirmation, failure, and local cleanup
  behavior.

### Modified Capabilities

- `setline-workout-player`: Return the browser to account choice with a clean
  local state only after successful account deletion.

## Impact

- Better Auth configuration and the existing `/api/auth/*` Worker route.
- Client auth helpers, authenticated account controls, and local sync/state
  cleanup.
- Privacy notice and focused tests.
- No new dependency, D1 migration, production configuration, or deployment.
