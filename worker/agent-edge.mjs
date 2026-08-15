/**
 * Portable agent-edge handler — copy or generate into each product.
 * Spec: foundry/ops/docs/agent-indexing-standard.md
 *
 * Usage in worker.mjs (before openNext.fetch):
 *   import { handleAgentEdge } from './agent-edge.mjs'
 *   const agent = handleAgentEdge(request)
 *   if (agent) return agent
 */

/** @type {{ name: string, url: string, llmsTxt: string, llmsFullTxt?: string, indexMd: string, catalog: object }} */
// biome-ignore format: generated payload from apply-agent-surfaces (JSON keys/quotes)
export const AGENT_SURFACE = {
  name: "Setline",
  url: "https://setline.significanthobbies.com",
  llmsFullTxt:
    "# Setline \u2014 full agent brief\n\niPhone app that runs a written strength, cardio and mobility programme one set at a time, records what was actually lifted, and measures each exercise against an authored target.\n\n## Index\n\n# Setline\n\nFollow your training plan. Record the truth.\n\nAn iPhone app that runs a written strength, cardio and mobility programme one set\nat a time, records what was actually lifted, and shows how far each exercise is\nfrom an authored target.\n\nStatus: in development. Not on the App Store yet. Free. iPhone only.\n\n## What it does\n\n- Resolves a dated programme day by day, including week-dependent rules such as\n  added sets, interval round counts and scheduled reassessments\n- Structured set targets: rep ranges, absolute, relative, bodyweight or assisted\n  load, reps in reserve, RPE, tempo, per-side work, and rest as a band\n- Excludes warm-up, preparation and cooldown work from volume, records and\n  progression decisions\n- Records one set as several segments, so 5 reps x 40 kg followed by\n  2 reps x 30 kg stays a single set\n- Times the set itself, separately from rest; rest is anchored to a wall-clock end\n  time and notifies on completion\n- Measures a current value per exercise (estimated 1RM, top set load, max\n  repetitions, best hold, longest distance, best pace, range of motion) against an\n  authored target, with rate of change and projected arrival\n- Cites the session behind every measured value\n- Applies double progression using the programme's own load increments\n- Carries a bundled movement library across strength, stamina, mobility and\n  flexibility, plus the CrossFit movement vocabulary\n- Exports and imports all local data as versioned JSON\n\n## What it refuses to do\n\n- Invent, estimate or interpolate a value it has not recorded\n- Draw a trend from fewer than two comparable sessions\n- Rewrite an authored plan when a session deviates; deviations are recorded as\n  deviations and authored positions are kept\n- Require an account or a network connection to run a workout\n\n## Not yet built\n\nApple Health heart-rate zones and VO2 max, an Apple Watch app, AMRAP, EMOM and\nFor Time scoring, range-of-motion assessments, and on-device workout generation.\nThese are not claimed as shipped.\n\n## Agent entrypoints\n\n- https://setline.significanthobbies.com/llms.txt\n- https://setline.significanthobbies.com/api/ai\n- https://setline.significanthobbies.com/index.md\n\n## Product links\n\n- Home: https://setline.significanthobbies.com/ \u2014 What Setline does, how one set is recorded, and what it refuses to do\n- Privacy: https://setline.significanthobbies.com/privacy \u2014 Device and private cloud data handling\n- Terms: https://setline.significanthobbies.com/terms \u2014 Product terms\n- Changelog: https://setline.significanthobbies.com/changelog \u2014 Verified product releases\n\n## Machine surfaces\n\n- https://setline.significanthobbies.com/llms.txt\n- https://setline.significanthobbies.com/llms-full.txt\n- https://setline.significanthobbies.com/api/ai\n- https://setline.significanthobbies.com/index.md\n- https://setline.significanthobbies.com/sitemap.xml\n- https://setline.significanthobbies.com/robots.txt\n\n## Contact\n\n- Owner: https://sarthakagrawal.dev\n- Agent email for directory verification: sarthakagrawal@agentmail.to\n",
  llmsTxt:
    "# Setline\n\n> iPhone app that runs a written strength, cardio and mobility programme one set at a time, records what was actually lifted, and measures each exercise against an authored target.\n\n## Product\n\n- [Home](https://setline.significanthobbies.com/): What Setline does, how one set is recorded, and what it refuses to do\n- [Privacy](https://setline.significanthobbies.com/privacy): Device and private cloud data handling\n- [Terms](https://setline.significanthobbies.com/terms): Product terms\n- [Changelog](https://setline.significanthobbies.com/changelog): Verified product releases\n\n## Machine surfaces\n\n- [Agent catalog](https://setline.significanthobbies.com/api/ai): JSON inventory of public surfaces\n- [Homepage markdown](https://setline.significanthobbies.com/index.md): Product brief without JS\n- [This index](https://setline.significanthobbies.com/llms.txt)\n",
  indexMd:
    "# Setline\n\nFollow your training plan. Record the truth.\n\nAn iPhone app that runs a written strength, cardio and mobility programme one set\nat a time, records what was actually lifted, and shows how far each exercise is\nfrom an authored target.\n\nStatus: in development. Not on the App Store yet. Free. iPhone only.\n\n## What it does\n\n- Resolves a dated programme day by day, including week-dependent rules such as\n  added sets, interval round counts and scheduled reassessments\n- Structured set targets: rep ranges, absolute, relative, bodyweight or assisted\n  load, reps in reserve, RPE, tempo, per-side work, and rest as a band\n- Excludes warm-up, preparation and cooldown work from volume, records and\n  progression decisions\n- Records one set as several segments, so 5 reps x 40 kg followed by\n  2 reps x 30 kg stays a single set\n- Times the set itself, separately from rest; rest is anchored to a wall-clock end\n  time and notifies on completion\n- Measures a current value per exercise (estimated 1RM, top set load, max\n  repetitions, best hold, longest distance, best pace, range of motion) against an\n  authored target, with rate of change and projected arrival\n- Cites the session behind every measured value\n- Applies double progression using the programme's own load increments\n- Carries a bundled movement library across strength, stamina, mobility and\n  flexibility, plus the CrossFit movement vocabulary\n- Exports and imports all local data as versioned JSON\n\n## What it refuses to do\n\n- Invent, estimate or interpolate a value it has not recorded\n- Draw a trend from fewer than two comparable sessions\n- Rewrite an authored plan when a session deviates; deviations are recorded as\n  deviations and authored positions are kept\n- Require an account or a network connection to run a workout\n\n## Not yet built\n\nApple Health heart-rate zones and VO2 max, an Apple Watch app, AMRAP, EMOM and\nFor Time scoring, range-of-motion assessments, and on-device workout generation.\nThese are not claimed as shipped.\n\n## Agent entrypoints\n\n- https://setline.significanthobbies.com/llms.txt\n- https://setline.significanthobbies.com/api/ai\n- https://setline.significanthobbies.com/index.md\n",
  catalog: {
    name: "Setline",
    version: "1",
    url: "https://setline.significanthobbies.com",
    llms: "https://setline.significanthobbies.com/llms.txt",
    llmsFull: "https://setline.significanthobbies.com/llms-full.txt",
    sitemap: "https://setline.significanthobbies.com/sitemap.xml",
    robots: "https://setline.significanthobbies.com/robots.txt",
    markdown: {
      suffix: ".md",
      negotiation: true,
    },
    surfaces: [
      {
        id: "home",
        url: "https://setline.significanthobbies.com/",
        md: "https://setline.significanthobbies.com/index.md",
        kind: "static",
        description:
          "What Setline does, how one set is recorded, and what it refuses to do",
      },
      {
        id: "privacy",
        url: "https://setline.significanthobbies.com/privacy",
        md: "https://setline.significanthobbies.com/privacy.md",
        kind: "static",
        description: "Device and private cloud data handling",
      },
      {
        id: "terms",
        url: "https://setline.significanthobbies.com/terms",
        md: "https://setline.significanthobbies.com/terms.md",
        kind: "static",
        description: "Product terms",
      },
      {
        id: "changelog",
        url: "https://setline.significanthobbies.com/changelog",
        md: "https://setline.significanthobbies.com/changelog.md",
        kind: "static",
        description: "Verified product releases",
      },
    ],
    auth: {
      public: true,
      notes: "Auth-walled app routes are not agent-indexed unless listed here.",
    },
  },
};

/**
 * @param {Request} request
 * @returns {Response | null}
 */
export function handleAgentEdge(request) {
  if (request.method !== "GET" && request.method !== "HEAD") return null;
  const url = new URL(request.url);
  const path = url.pathname === "" ? "/" : url.pathname;

  if (path === "/llms.txt") {
    return text(AGENT_SURFACE.llmsTxt, "text/plain; charset=utf-8");
  }
  if (path === "/llms-full.txt" && AGENT_SURFACE.llmsFullTxt) {
    return text(AGENT_SURFACE.llmsFullTxt, "text/plain; charset=utf-8");
  }
  if (path === "/index.md") {
    return text(AGENT_SURFACE.indexMd, "text/markdown; charset=utf-8");
  }
  if (path === "/sitemap.xml") {
    return text(
      sitemapForCatalog(catalogForOrigin(url.origin)),
      "application/xml; charset=utf-8",
    );
  }
  if (path === "/robots.txt") {
    return text(robotsForOrigin(url.origin), "text/plain; charset=utf-8");
  }
  if (path === "/api/ai") {
    return json(catalogForOrigin(url.origin));
  }

  // Homepage markdown negotiation
  if ((path === "/" || path === "") && wantsMarkdown(request)) {
    return text(AGENT_SURFACE.indexMd, "text/markdown; charset=utf-8", {
      Link: '</index.md>; rel="alternate"; type="text/markdown"',
      Vary: "Accept",
    });
  }

  return null;
}

function catalogForOrigin(origin) {
  return {
    ...AGENT_SURFACE.catalog,
    url: origin,
    llms: `${origin}/llms.txt`,
    llmsFull: `${origin}/llms-full.txt`,
    sitemap: `${origin}/sitemap.xml`,
    robots: `${origin}/robots.txt`,
    surfaces: (AGENT_SURFACE.catalog.surfaces || []).map((surface) => ({
      ...surface,
      url: forOrigin(surface.url, origin),
      md: forOrigin(surface.md, origin),
    })),
  };
}

function forOrigin(value, origin) {
  return String(value).split(AGENT_SURFACE.url).join(origin);
}

function sitemapForCatalog(catalog) {
  const routes = catalog.surfaces
    .map((surface) => `  <url><loc>${escapeXml(surface.url)}</loc></url>`)
    .join("\n");
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${routes}\n</urlset>\n`;
}

function robotsForOrigin(origin) {
  return `User-agent: *
Allow: /

Sitemap: ${origin}/sitemap.xml
# Agent indexing
Allow: /llms.txt
Allow: /llms-full.txt
Allow: /index.md
Allow: /api/ai
`;
}

function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function wantsMarkdown(request) {
  const accept = (request.headers.get("accept") || "").toLowerCase();
  if (!accept.includes("text/markdown")) return false;
  if (!accept.includes("text/html")) return true;
  return accept.indexOf("text/markdown") < accept.indexOf("text/html");
}

function text(body, type, extra = {}) {
  return new Response(body, {
    status: 200,
    headers: {
      "Content-Type": type,
      "Cache-Control": "public, max-age=300",
      ...extra,
    },
  });
}

function json(data) {
  return new Response(`${JSON.stringify(data, null, 2)}\n`, {
    status: 200,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}
