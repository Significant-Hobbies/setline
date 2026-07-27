import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

async function render(pathname = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the Setline restoration shell and public legal pages", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Setline — Workout execution tracker<\/title>/i);
  assert.match(html, /SETLINE · LOADING/);
  assert.match(html, /Restoring this device’s saved state\./);
  assert.doesNotMatch(html, /Your site is taking shape|codex-preview|react-loading-skeleton/i);

  const [privacy, terms] = await Promise.all([render("/privacy"), render("/terms")]);
  assert.equal(privacy.status, 200);
  assert.equal(terms.status, 200);
  assert.match(await privacy.text(), /Privacy notice/);
  assert.match(await terms.text(), /Terms of use/);
});

test("ships the installable offline shell and local workout state", async () => {
  const [manifest, serviceWorker, page, workoutState, programme, authSchema] = await Promise.all([
    readFile(new URL("../app/manifest.ts", import.meta.url), "utf8"),
    readFile(new URL("../public/sw.js", import.meta.url), "utf8"),
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/workout-state.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/programme.ts", import.meta.url), "utf8"),
    readFile(new URL("../worker/schema.ts", import.meta.url), "utf8"),
  ]);

  assert.match(manifest, /display:\s*"standalone"/);
  assert.match(manifest, /icon-192\.png/);
  assert.match(serviceWorker, /setline-shell-v3/);
  assert.match(serviceWorker, /caches\.match/);
  assert.match(serviceWorker, /url\.pathname\.startsWith\("\/api\/"\)/);
  assert.match(workoutState, /setline:v1/);
  assert.match(workoutState, /restEndsAt/);
  assert.match(workoutState, /version:\s*3/);
  assert.match(workoutState, /legacy-upper-a/);
  assert.match(workoutState, /actualDurationSeconds/);
  assert.match(programme, /27 Jul 2026/);
  assert.match(programme, /PROGRAMME_SCHEDULE/);
  assert.match(programme, /hard-cardio/);
  assert.match(
    authSchema,
    /expiresAt:\s*integer\("expiresAt",\s*\{\s*mode:\s*"timestamp"\s*\}\)\.notNull\(\)/,
  );
  assert.match(page, /localStorage/);
  assert.match(page, /ORDER LOCKED · SESSION PLAN/);
  assert.match(page, /CORRECT RECORDED STEP/);
  assert.match(page, /Save correction/);
  assert.match(page, /min:sec/);
  assert.match(page, /className="rail-edit"/);
  assert.match(page, /quality: null/);
  assert.match(page, /activeIndex: nextIndex/);

  await Promise.all([
    access(new URL("../public/icon-192.png", import.meta.url)),
    access(new URL("../public/icon-512.png", import.meta.url)),
    access(new URL("../public/favicon.png", import.meta.url)),
  ]);
});
