import assert from "node:assert/strict";
import { readFile, stat } from "node:fs/promises";
import test from "node:test";

const ORIGIN = "https://setline.significanthobbies.com";

/**
 * The public site is plain files on GitHub Pages. Nothing runs at request time, so
 * nothing can reconcile the agent surfaces with each other or rewrite a path.
 * These tests are that reconciliation: the sitemap, the agent catalog, `llms.txt`
 * and the landing page have to agree, and every path any of them advertises has to
 * resolve to a file that is actually published.
 */
function publicFile(name) {
  return new URL(`../public/${name}`, import.meta.url);
}

async function readPublic(name) {
  return readFile(publicFile(name), "utf8");
}

/**
 * Asserts a public path resolves to a file, in the order GitHub Pages tries: the
 * exact file, then `.html`, then a directory index.
 */
async function assertServable(path) {
  const trimmed = path === "/" ? "index.html" : path.replace(/^\//, "");
  const candidates = trimmed.includes(".")
    ? [trimmed]
    : [trimmed, `${trimmed}.html`, `${trimmed}/index.html`];
  for (const candidate of candidates) {
    try {
      await stat(publicFile(candidate));
      return candidate;
    } catch {
      continue;
    }
  }
  assert.fail(`${path} resolves to none of: ${candidates.join(", ")}`);
}

test("the agent catalog lives at the path robots.txt advertises", async () => {
  const catalog = JSON.parse(await readPublic("api/ai"));
  assert.equal(catalog.url, ORIGIN);
  const robots = await readPublic("robots.txt");
  assert.match(robots, /Allow: \/api\/ai/);
  // A second copy would drift; api/ai is the only one.
  await assert.rejects(stat(publicFile("api-ai.json")));
});

test("the agent catalog is valid JSON at its advertised path", async () => {
  // GitHub Pages serves files as-is and cannot set a Content-Type for an
  // extensionless path, so the body itself has to be unambiguously parsable.
  const raw = await readPublic("api/ai");
  const catalog = JSON.parse(raw);
  for (const field of [
    "name",
    "url",
    "llms",
    "sitemap",
    "markdown",
    "surfaces",
  ]) {
    assert.ok(field in catalog, `/api/ai must carry ${field}`);
  }
  assert.doesNotMatch(
    raw.trimStart()[0],
    /[<#]/,
    "must not be HTML or markdown",
  );
});

test("the site is published as-is under its own domain", async () => {
  // Jekyll would otherwise drop dotfiles and reinterpret the markdown mirrors.
  await stat(publicFile(".nojekyll"));
  const cname = (await readPublic("CNAME")).trim();
  assert.equal(cname, ORIGIN.replace("https://", ""));
});

test("no Cloudflare-specific configuration survives", async () => {
  for (const cloudflareOnly of ["_headers", "_redirects", "_worker.js"]) {
    await assert.rejects(
      stat(publicFile(cloudflareOnly)),
      `${cloudflareOnly} is Cloudflare-only and would be dead config on GitHub Pages`,
    );
  }
  await assert.rejects(stat(new URL("../wrangler.jsonc", import.meta.url)));
});

test("every catalogued surface is in the sitemap and exists as a file", async () => {
  const catalog = JSON.parse(await readPublic("api/ai"));
  const sitemap = await readPublic("sitemap.xml");
  assert.ok(catalog.surfaces.length > 0);
  for (const surface of catalog.surfaces) {
    assert.ok(
      surface.url.startsWith(ORIGIN),
      `${surface.url} must be on the canonical origin`,
    );
    assert.ok(
      sitemap.includes(`<loc>${surface.url}</loc>`),
      `${surface.url} is catalogued but missing from sitemap.xml`,
    );
    await assertServable(surface.url.slice(ORIGIN.length));
    if (surface.md) {
      await stat(publicFile(surface.md.slice(ORIGIN.length + 1)));
    }
  }
});

test("every sitemap entry is catalogued, so neither list can drift", async () => {
  const catalog = JSON.parse(await readPublic("api/ai"));
  const sitemap = await readPublic("sitemap.xml");
  const catalogued = new Set(catalog.surfaces.map((surface) => surface.url));
  const listed = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
  assert.ok(listed.length > 0);
  for (const url of listed) {
    assert.ok(
      catalogued.has(url),
      `${url} is in the sitemap but not in /api/ai`,
    );
  }
});

test("llms.txt points only at surfaces that exist", async () => {
  const llms = await readPublic("llms.txt");
  const links = [...llms.matchAll(/\]\((https:\/\/[^)]+)\)/g)].map((m) => m[1]);
  assert.ok(links.length > 0);
  for (const link of links) {
    assert.ok(
      link.startsWith(ORIGIN),
      `${link} must be on the canonical origin`,
    );
    await assertServable(link.slice(ORIGIN.length));
  }
});

test("llms-full.txt embeds the homepage markdown verbatim", async () => {
  const [full, index] = await Promise.all([
    readPublic("llms-full.txt"),
    readPublic("index.md"),
  ]);
  assert.ok(
    full.includes(index.trim()),
    "the full brief must not paraphrase index.md",
  );
});

test("the landing page declares the canonical URL and its own OG image", async () => {
  const html = await readPublic("index.html");
  assert.match(html, new RegExp(`<link rel="canonical" href="${ORIGIN}/">`));
  assert.match(
    html,
    new RegExp(`<meta property="og:image" content="${ORIGIN}/og.png">`),
  );
  // The analytics identifier is a tracked value and must survive page rewrites.
  assert.match(html, /phc_qgiAarw4Co4pw9fz3Fxj4UJaHmqzFetqs4JrXhGc35Nd/);
  assert.match(html, /project_id:"setline"/);
});

test("every asset the landing page references exists", async () => {
  const html = await readPublic("index.html");
  const references = [
    ...[...html.matchAll(/<img[^>]+src="\/([^"]+)"/g)].map((m) => m[1]),
    ...[...html.matchAll(/<link[^>]+href="\/([^"]+)"/g)].map((m) => m[1]),
  ];
  assert.ok(
    references.length > 0,
    "expected the landing page to show the product",
  );
  for (const reference of references) {
    await stat(publicFile(reference));
  }
});

test("the landing page states its pre-release status rather than implying a download", async () => {
  const html = await readPublic("index.html");
  assert.match(html, /Not on the App Store yet/);
  assert.doesNotMatch(
    html,
    /apps\.apple\.com|Download on the App Store|testflight\.apple\.com/i,
    "no store or TestFlight link may appear until one genuinely exists",
  );
});

test("the landing page avoids the weak words the landing standard bans", async () => {
  const html = await readPublic("index.html");
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

test("the manifest uses the tracked palette rather than the old placeholder navy", async () => {
  const manifest = JSON.parse(await readPublic("manifest.webmanifest"));
  assert.equal(manifest.background_color, "#f7f6f0");
  assert.equal(manifest.theme_color, "#18262e");
  for (const icon of manifest.icons) {
    await stat(publicFile(icon.src.replace(/^\//, "")));
  }
});

test("the service worker only evicts its own caches and unregisters", async () => {
  const sw = await readPublic("sw.js");
  assert.match(sw, /caches\.delete/);
  assert.match(sw, /registration\.unregister\(\)/);
  // A returning visitor must never be served a shell for a site that is gone.
  assert.doesNotMatch(sw, /addAll|APP_SHELL/);
});

const PAGES = ["index.html", "privacy.html", "terms.html", "changelog.html"];

test("every page ships on the tracked palette, not the placeholder navy", async () => {
  for (const page of PAGES) {
    const html = await readPublic(page);
    for (const placeholder of ["#0f172a", "#fbbf24", "#e2e8f0", "#38bdf8"]) {
      assert.ok(
        !html.includes(placeholder),
        `${page} still uses the placeholder colour ${placeholder}`,
      );
    }
    assert.ok(
      html.includes("#f7f6f0") || html.includes("/legal.css"),
      `${page} must use the tracked tokens directly or via legal.css`,
    );
  }
});

test("every asset any page references exists", async () => {
  for (const page of PAGES) {
    const html = await readPublic(page);
    const references = [
      ...[...html.matchAll(/<img[^>]+src="\/([^"]+)"/g)].map((m) => m[1]),
      ...[...html.matchAll(/<link[^>]+href="\/([^"]+)"/g)].map((m) => m[1]),
    ];
    assert.ok(references.length > 0, `${page} references no local assets`);
    for (const reference of references) {
      await stat(publicFile(reference));
    }
  }
});

test("no page claims an account, a sign-in or a server copy", async () => {
  // The account layer was deleted. A public page that still offers it would be a
  // false statement about where a person's training data goes.
  const claims = [
    /Google sign-in/i,
    /Sign in with Apple/i,
    /\bsign in to\b/i,
    /private cloud/i,
    // \b keeps this off "iCloud sync", which is a named Apple feature the pages
    // may legitimately describe as not yet built.
    /\bcloud (copy|sync)\b/i,
    /user-scoped/i,
  ];
  for (const page of [...PAGES, "privacy.md", "terms.md", "changelog.md"]) {
    const text = await readPublic(page);
    for (const claim of claims) {
      const match = text.match(claim);
      // The changelog records the removal, so it may name what was removed.
      if (match && page.startsWith("changelog")) continue;
      assert.ok(!match, `${page} still claims "${match?.[0]}"`);
    }
  }
});

test("the privacy notice discloses every third-party script the site loads", async () => {
  // Tying disclosure to the actual markup means adding a tracker without saying
  // so in the notice fails here rather than shipping quietly.
  const hosts = new Set();
  for (const page of PAGES) {
    const html = await readPublic(page);
    for (const [, host] of html.matchAll(
      /(?:src|href)="https?:\/\/([^/"]+)/g,
    )) {
      if (host.endsWith("setline.significanthobbies.com")) continue;
      hosts.add(host);
    }
  }
  const [privacyHtml, privacyMd] = await Promise.all([
    readPublic("privacy.html"),
    readPublic("privacy.md"),
  ]);
  // Documentation links are not scripts; only script/style origins need naming.
  const scriptHosts = [...hosts].filter(
    (host) => host === "us.i.posthog.com" || host === "sassmaker.com",
  );
  assert.ok(scriptHosts.length > 0, "expected to find the analytics origins");
  const named = { "us.i.posthog.com": "PostHog", "sassmaker.com": "sassmaker" };
  for (const host of scriptHosts) {
    for (const [label, copy] of [
      ["privacy.html", privacyHtml],
      ["privacy.md", privacyMd],
    ]) {
      assert.match(
        copy,
        new RegExp(named[host], "i"),
        `${label} must disclose ${host}`,
      );
    }
  }
});

test("the privacy notice and terms carry a date and the health disclaimer", async () => {
  for (const page of ["privacy.html", "privacy.md", "terms.html", "terms.md"]) {
    const text = await readPublic(page);
    assert.match(
      text,
      /(Last updated|updated) 16 August 2026/,
      `${page} must state when it was last updated`,
    );
  }
  for (const page of ["terms.html", "terms.md"]) {
    const text = await readPublic(page);
    assert.match(text, /not medical advice/i, `${page} must disclaim advice`);
  }
});

test("no source file still references Cloudflare or the removed backend", async () => {
  for (const [name, file] of [["package manifest", "../package.json"]]) {
    const contents = await readFile(new URL(file, import.meta.url), "utf8");
    for (const gone of [
      "worker/index.ts",
      "d1_databases",
      "better-auth",
      "drizzle",
    ]) {
      assert.ok(
        !contents.includes(gone),
        `${name} still references ${gone} after the backend removal`,
      );
    }
  }
});
