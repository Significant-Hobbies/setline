import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const [source, migration] = await Promise.all([
  readFile(new URL("../worker/mcp.ts", import.meta.url), "utf8"),
  readFile(new URL("../migrations/0002_mcp_read_tokens.sql", import.meta.url), "utf8"),
]);

test("Setline stores read-token hashes and owner-scopes revocation", () => {
  assert.match(migration, /token_hash TEXT NOT NULL UNIQUE/);
  assert.doesNotMatch(migration, /\btoken\s+TEXT/i);
  assert.match(source, /WHERE id = \? AND user_id = \? AND revoked_at IS NULL/);
  assert.match(source, /WHERE token_hash = \? AND revoked_at IS NULL/);
});

test("Setline MCP exposes projections without execution or whole-state writes", () => {
  const readHandler = source.slice(source.indexOf("export async function handleMcpRead"));
  assert.match(readHandler, /request\.method !== "GET"/);
  assert.doesNotMatch(readHandler, /INSERT INTO workout_state|UPDATE workout_state/);
  assert.doesNotMatch(readHandler, /acceptRecommendation|startWorkout|completeSet|syncState/);
  assert.match(readHandler, /historySummary/);
  assert.match(readHandler, /provenance: "calculated-from-recorded-history"/);
});

test("Setline pages remain bounded and state parsing fails closed", () => {
  assert.match(source, /const MAX_LIMIT = 100/);
  assert.match(source, /parseStoredState/);
  assert.match(source, /Treat corrupt or unsupported cloud state as unavailable/);
});
