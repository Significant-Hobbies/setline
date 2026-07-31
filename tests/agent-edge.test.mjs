import assert from "node:assert/strict";
import test from "node:test";
import { handleAgentEdge } from "../worker/agent-edge.mjs";

const ORIGINS = [
  "https://setline.significanthobbies.com",
  "https://setline-preview.example",
];

for (const origin of ORIGINS) {
  test(`keeps sitemap and robots on the request origin: ${origin}`, async () => {
    const sitemap = handleAgentEdge(new Request(`${origin}/sitemap.xml`));
    assert.ok(sitemap);
    assert.equal(sitemap.status, 200);
    assert.match(sitemap.headers.get("content-type") ?? "", /application\/xml/);

    const sitemapBody = await sitemap.text();
    for (const path of ["/", "/privacy", "/terms", "/changelog"]) {
      assert.match(sitemapBody, new RegExp(`<loc>${origin}${path}</loc>`));
    }
    if (origin !== "https://setline.significanthobbies.com") {
      assert.doesNotMatch(
        sitemapBody,
        /https:\/\/setline\.significanthobbies\.com/,
      );
    }

    const robots = handleAgentEdge(new Request(`${origin}/robots.txt`));
    assert.ok(robots);
    assert.equal(robots.status, 200);
    assert.match(
      await robots.text(),
      new RegExp(`Sitemap: ${origin}/sitemap\\.xml`),
    );
  });
}
