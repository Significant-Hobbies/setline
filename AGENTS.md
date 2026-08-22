# Setline agent instructions

- Read `PROJECT_STATUS.md`, `PRODUCT.md`, and `DESIGN.md` before broad work.
- Keep Setline's source, product planning, tests, and release configuration in
  this repository. Site Health may catalog Setline but does not own its product
  source.
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
- Setline has no product-specific backend. Optional signed-in synchronization
  uses PersonalSyncKit and Personal Platform; never put a network call in the
  active workout path.
- The public landing source of truth is `ios-landings` (`PRODUCT=setline`),
  and it is the only one. This repo carries no landing copy: the retired
  `site/` fork and its GitHub Pages workflow both claimed
  `setline.significanthobbies.com`, which Cloudflare already serves. Landing
  edits belong in `ios-landings/products/setline/`.
- Setline owns no Cloudflare runtime or database. Its shared signed-in state is
  owned by Personal Platform.
- Do not change DNS or publish a release without explicit approval.
