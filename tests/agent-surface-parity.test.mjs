import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

import { handleAgentEdge } from "../worker/agent-edge.mjs";

const ORIGIN = "https://setline.significanthobbies.com";

/**
 * The Worker serves agent surfaces from inline strings while `public/` holds the
 * same content as static files. Either can be the one an agent reads, depending
 * on how the site is deployed, so the two must never drift apart.
 */
async function serve(path) {
  const response = handleAgentEdge(new Request(`${ORIGIN}${path}`));
  assert.ok(response, `expected the agent edge to handle ${path}`);
  return response.text();
}

for (const [path, file] of [
  ["/llms.txt", "llms.txt"],
  ["/llms-full.txt", "llms-full.txt"],
  ["/index.md", "index.md"],
]) {
  test(`worker ${path} matches public/${file} byte for byte`, async () => {
    const served = await serve(path);
    const stored = await readFile(
      new URL(`../public/${file}`, import.meta.url),
      "utf8",
    );
    assert.equal(served, stored);
  });
}

test("worker /api/ai matches public/api-ai.json", async () => {
  const served = JSON.parse(await serve("/api/ai"));
  const stored = JSON.parse(
    await readFile(new URL("../public/api-ai.json", import.meta.url), "utf8"),
  );
  assert.deepEqual(served, stored);
});

test("every catalog surface appears in the static sitemap", async () => {
  const catalog = JSON.parse(await serve("/api/ai"));
  const sitemap = await readFile(
    new URL("../public/sitemap.xml", import.meta.url),
    "utf8",
  );
  for (const surface of catalog.surfaces) {
    assert.ok(
      sitemap.includes(`<loc>${surface.url}</loc>`),
      `${surface.url} is catalogued but missing from public/sitemap.xml`,
    );
  }
});

test("the landing page declares the canonical URL and its own OG image", async () => {
  const html = await readFile(
    new URL("../public/index.html", import.meta.url),
    "utf8",
  );
  assert.match(html, new RegExp(`<link rel="canonical" href="${ORIGIN}/">`));
  assert.match(
    html,
    new RegExp(`<meta property="og:image" content="${ORIGIN}/og.png">`),
  );
  // The analytics identifier is a tracked value and must survive page rewrites.
  assert.match(html, /phc_qgiAarw4Co4pw9fz3Fxj4UJaHmqzFetqs4JrXhGc35Nd/);
  assert.match(html, /project_id:"setline"/);
});

test("landing page images all exist in public/", async () => {
  const html = await readFile(
    new URL("../public/index.html", import.meta.url),
    "utf8",
  );
  const sources = [...html.matchAll(/<img[^>]+src="\/([^"]+)"/g)].map(
    (match) => match[1],
  );
  assert.ok(
    sources.length > 0,
    "expected the landing page to show the product",
  );
  for (const source of sources) {
    await readFile(new URL(`../public/${source}`, import.meta.url));
  }
});

test("the landing page states its pre-release status rather than implying a download", async () => {
  const html = await readFile(
    new URL("../public/index.html", import.meta.url),
    "utf8",
  );
  assert.match(html, /Not on the App Store yet/);
  assert.doesNotMatch(
    html,
    /apps\.apple\.com|Download on the App Store|testflight\.apple\.com/i,
    "no store or TestFlight link may appear until one genuinely exists",
  );
});

test("the landing page avoids the weak words the landing standard bans", async () => {
  const html = await readFile(
    new URL("../public/index.html", import.meta.url),
    "utf8",
  );
  const body = html
    .replace(/<style[\s\S]*?<\/style>/g, "")
    .replace(/<script[\s\S]*?<\/script>/g, "");
  for (const word of [
    "powerful",
    "seamless",
    "robust",
    "amazing",
    "cutting-edge",
    "revolutionary",
  ]) {
    assert.doesNotMatch(
      body,
      new RegExp(`\\b${word}\\b`, "i"),
      `"${word}" is banned copy`,
    );
  }
});
