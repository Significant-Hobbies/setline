import { links, site } from "../site.config";

export const prerender = true;

export function GET() {
  const body = [
    `# ${site.name}`,
    `> ${site.summary}`,
    "",
    "## When to use this",
    "- Best fit: following a written strength, cardio, and mobility programme one set at a time on iOS",
    "- Best fit: recording what was actually lifted and measuring each exercise against an authored target",
    "- Not a fit: generic workout logging without a structured programme",
    "- Not a fit: social fitness tracking or leaderboard-style competition",
    "",
    "## Primary",
    `- [Product overview](${links.home}index.md): Canonical Markdown summary of ${site.name}.`,
    `- [Privacy](${links.privacy}): Current privacy policy.`,
    `- [Support](${links.support}): Support and feedback.`,
    `- [TestFlight](${links.testflight}): Current beta availability.`,
    "",
    "## Machine surfaces",
    `- [Agent catalog](${site.url}/api/ai)`,
    `- [OpenAPI spec](${site.url}/openapi.json)`,
    `- [Sitemap](${site.url}/sitemap.xml)`,
    `- [This index](${site.url}/llms.txt)`,
    "",
    "## Product boundaries",
    ...site.boundaries.map((item) => `- ${item}`),
    ""
  ].join("\n");
  return new Response(body, { headers: { "content-type": "text/plain; charset=utf-8" } });
}
