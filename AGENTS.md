# Setline agent instructions

- Read `PROJECT_STATUS.md`, `PRODUCT.md`, and `DESIGN.md` before broad work.
- Keep Setline's source, product planning, tests, and release configuration in
  this repository. Fleet Workspace may link to Setline but does not own its
  product source.
- Preserve authored programme and exercise order. User-directed skips, extras,
  partial/drop segments, and deferrals must remain explicit execution records,
  never silent programme rewrites.
- Keep active workouts device-first and functional without a network request.
- Keep recorded, calculated, authored, adjusted, and unavailable values
  visibly distinct.
- Use pnpm and the committed `pnpm-lock.yaml`.
- Run `pnpm run check` before broader release validation. For any change under
  `ios/`, run `pnpm quality:native` too — it is the gate CI runs on macOS
  (xcodegen, simulator unit and UI tests, release build, coverage floor).
- Setline has no backend. Do not reintroduce an account, a server, or a
  network call in the workout path.
- Setline uses no Cloudflare, no database and no hosting account. Do not add one.
- Do not change DNS or publish a release without explicit approval.
