import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

/**
 * Cross-file consistency checks for the iPhone app's configuration.
 *
 * These are values that live in two places and fail at runtime, on a device, with
 * an opaque error when they disagree — exactly the kind of mismatch a simulator
 * test suite will not notice. Reading the files is enough to catch it, so it runs
 * in the cheap check rather than waiting for hardware.
 */
async function readSource(path) {
  return readFile(new URL(`../${path}`, import.meta.url), "utf8");
}

test("the CloudKit container is identical in the entitlement and the source", async () => {
  const [entitlements, store] = await Promise.all([
    readSource("ios/Sources/Setline/Setline.entitlements"),
    readSource("ios/Sources/SetlineCore/Sync/CloudKitRecordStore.swift"),
  ]);

  const entitled = [
    ...entitlements.matchAll(/<string>(iCloud\.[^<]+)<\/string>/g),
  ].map((match) => match[1]);
  assert.equal(
    entitled.length,
    1,
    "expected exactly one iCloud container in the entitlement",
  );

  const declared = store.match(
    /containerIdentifier\s*=\s*"(iCloud\.[^"]+)"/,
  )?.[1];
  assert.equal(
    declared,
    entitled[0],
    "CloudKitRecordStore and the entitlement must name the same container",
  );
});

test("Setline is locked to the personal Apple team, not the company team", async () => {
  const [project, archive, simulator] = await Promise.all([
    readSource("ios/project.yml"),
    readSource("ios/scripts/archive.sh"),
    readSource("scripts/simulator-icloud-sync.sh"),
  ]);

  const personal = "8F7LXHTJZR";
  const company = "B97DAJX353";
  assert.match(project, new RegExp(`DEVELOPMENT_TEAM:\\s*${personal}`));
  assert.match(archive, new RegExp(`personal_team="${personal}"`));
  assert.match(simulator, new RegExp(`personal_team="${personal}"`));
  for (const [name, source] of [
    ["project.yml", project],
    ["archive.sh", archive],
    ["simulator-icloud-sync.sh", simulator],
  ]) {
    assert.ok(
      !source.includes(company),
      `${name} must not mention the Vault company team`,
    );
  }
});

test("the container is derived from the app's own bundle identifier", async () => {
  const [project, entitlements] = await Promise.all([
    readSource("ios/project.yml"),
    readSource("ios/Sources/Setline/Setline.entitlements"),
  ]);

  const bundleID = project.match(
    /PRODUCT_BUNDLE_IDENTIFIER:\s*(com\.significanthobbies\.setline)\s*$/m,
  )?.[1];
  assert.ok(bundleID, "expected the app bundle identifier in project.yml");
  assert.match(
    entitlements,
    new RegExp(`<string>iCloud\\.${bundleID}</string>`),
  );
});

test("the app claims CloudKit and nothing it does not use", async () => {
  const entitlements = await readSource(
    "ios/Sources/Setline/Setline.entitlements",
  );

  assert.match(entitlements, /com\.apple\.developer\.icloud-services/);
  assert.match(entitlements, /<string>CloudKit<\/string>/);
  // Setline syncs one person's own training. A shared or public database, or a
  // returning Sign in with Apple, would each be a change in what the app is.
  for (const unused of [
    "com.apple.developer.applesignin",
    "com.apple.developer.healthkit",
    "aps-environment",
  ]) {
    assert.ok(
      !entitlements.includes(unused),
      `${unused} is claimed but nothing in the app uses it`,
    );
  }
});

test("sync is disabled for every demo and interface-test launch", async () => {
  // A demo launch runs against a fixture. If one of them reached a real iCloud
  // account, its result would depend on what happened to be in that account, and a
  // screenshot run could write fixture data into somebody's real training.
  const model = await readSource("ios/Sources/Setline/AppModel.swift");
  const demoFlags = [...model.matchAll(/"(--[a-z-]+demo)"/g)].map(
    (match) => match[1],
  );
  const uniqueFlags = [...new Set(demoFlags)];
  assert.ok(
    uniqueFlags.length >= 8,
    "expected the demo launch flags to be listed",
  );

  const guard =
    model.match(/demoFlags: Set<String> = \[([\s\S]*?)\]/)?.[1] ?? "";
  for (const flag of uniqueFlags) {
    assert.ok(
      guard.includes(`"${flag}"`),
      `${flag} is a demo launch flag but is not in the set that disables sync`,
    );
  }
});
