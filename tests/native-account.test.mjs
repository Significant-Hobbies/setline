import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { createServer } from "vite";

let handoff;
let nativeState;
let vite;

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  handoff = await vite.ssrLoadModule("/worker/native-handoff.ts");
  nativeState = await vite.ssrLoadModule("/worker/native-state.ts");
});

test.after(async () => {
  await vite.close();
});

test("native authentication accepts only Setline's exact callback", () => {
  assert.equal(handoff.isAllowedNativeCallback("setline://auth"), true);
  assert.equal(handoff.isAllowedNativeCallback("setline://auth.evil.example"), false);
  assert.equal(handoff.isAllowedNativeCallback("https://setline.example/auth"), false);
});

test("native handoff codes are opaque and hash deterministically", async () => {
  const first = handoff.createNativeHandoffCode();
  const second = handoff.createNativeHandoffCode();
  assert.equal(first.length, 43);
  assert.notEqual(first, second);
  assert.equal(await handoff.hashNativeHandoffCode(first), await handoff.hashNativeHandoffCode(first));
  assert.notEqual(await handoff.hashNativeHandoffCode(first), await handoff.hashNativeHandoffCode(second));
});

test("native state requires schema one and an explicit base revision", () => {
  assert.deepEqual(
    nativeState.parseNativeStateEnvelope({ document: { schemaVersion: 1 }, baseRevision: null }),
    { document: { schemaVersion: 1 }, baseRevision: null },
  );
  assert.equal(
    nativeState.parseNativeStateEnvelope({ document: { schemaVersion: 2 }, baseRevision: null }),
    null,
  );
  assert.equal(
    nativeState.parseNativeStateEnvelope({ document: { schemaVersion: 1 } }),
    null,
  );
  assert.equal(
    nativeState.parseNativeStateEnvelope({ document: { schemaVersion: 1 }, baseRevision: -1 }),
    null,
  );
});

test("native Apple auth validates the bundle audience and never links by email implicitly", async () => {
  const [auth, client] = await Promise.all([
    readFile(new URL("../worker/auth.ts", import.meta.url), "utf8"),
    readFile(new URL("../ios/Sources/Setline/NativeAccountClient.swift", import.meta.url), "utf8"),
  ]);

  assert.match(auth, /appBundleIdentifier:\s*appleBundleIdentifier/);
  assert.match(auth, /disableImplicitLinking:\s*true/);
  assert.match(auth, /allowDifferentEmails:\s*true/);
  assert.match(client, /\/api\/auth\/sign-in\/social/);
  assert.match(client, /\/api\/auth\/link-social/);
  assert.match(client, /set-auth-token/);
});
