# Archived specs

Specifications for capabilities that were built and then removed. They are kept
because the reasoning is worth having, not because they describe the product.
Nothing here is a current requirement.

- `account-data-deletion` — archived 2026-08-16. Specified authenticated
  self-service deletion of a Setline account and its private cloud copy, via
  Better Auth and D1 foreign-key cascades. Every part of the surface it governed
  was deleted with the Cloudflare Worker on 2026-08-16: there is no account, no
  session, no `workout_state` row and no server to delete anything from. Deleting
  the app, or Reset local data, now removes the only copy that exists. The
  requirement that the privacy notice describe self-service account deletion was
  retired at the same time; the notice now states that nothing is collected.
