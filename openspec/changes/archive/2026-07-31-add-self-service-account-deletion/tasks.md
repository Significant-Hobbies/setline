## 1. Contract and auth

- [x] 1.1 Enable Better Auth user deletion without adding a custom API or D1
  migration.
- [x] 1.2 Add a client deletion helper that treats only confirmed success as
  deletion.

## 2. Account management

- [x] 2.1 Add preserve-lane, keyboard-usable deletion confirmation to the
  authenticated account menu.
- [x] 2.2 Clear the deleted account's browser workout and auth/sync state only
  after confirmed success; preserve it on failure.
- [x] 2.3 Update the privacy notice with accurate self-service deletion and
  Google-revocation boundaries.

## 3. Verification and delivery

- [x] 3.1 Add focused tests for auth configuration, cascade contract, client
  cleanup ordering, confirmation behavior, and privacy copy.
- [x] 3.2 Run strict OpenSpec validation and the complete Setline check.
- [x] 3.3 Capture preserve-lane browser evidence at 390, 768, and 1440 pixels;
  pass independent critique/audit with zero unresolved P0/P1.
- [x] 3.4 Archive the OpenSpec change and update PROJECT_STATUS. Delivery is
  tracked by the linked pull request that closes GitHub issue #13.
