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

test("server-renders the Setline workout overview", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Setline — Workout execution tracker<\/title>/i);
  assert.match(html, /Upper A is set\./);
  assert.match(html, /Start workout/);
  assert.match(html, /Ready without a signal/);
  assert.match(html, /SAMPLE/);
  assert.doesNotMatch(html, /Your site is taking shape|codex-preview|react-loading-skeleton/i);
});

test("ships the installable offline shell and local workout state", async () => {
  const [manifest, serviceWorker, page] = await Promise.all([
    readFile(new URL("../app/manifest.ts", import.meta.url), "utf8"),
    readFile(new URL("../public/sw.js", import.meta.url), "utf8"),
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
  ]);

  assert.match(manifest, /display:\s*"standalone"/);
  assert.match(manifest, /icon-192\.png/);
  assert.match(serviceWorker, /setline-shell-v1/);
  assert.match(serviceWorker, /caches\.match/);
  assert.match(page, /setline:v1/);
  assert.match(page, /restEndsAt/);
  assert.match(page, /localStorage/);
  assert.match(page, /ORDER LOCKED · SESSION PLAN/);
  assert.match(page, /quality: null/);
  assert.match(page, /activeIndex: nextIndex/);

  await Promise.all([
    access(new URL("../public/icon-192.png", import.meta.url)),
    access(new URL("../public/icon-512.png", import.meta.url)),
    access(new URL("../public/favicon.png", import.meta.url)),
  ]);
});
