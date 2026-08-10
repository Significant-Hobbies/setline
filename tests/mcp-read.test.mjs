import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";

let mcp;
let vite;

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  mcp = await vite.ssrLoadModule("/worker/mcp.ts");
});

test.after(async () => {
  await vite.close();
});

test("read tokens are scoped, hashed, and reject browser credentials", async () => {
  const token = mcp.createReadToken();
  assert.match(token, /^setline_read_[A-Za-z0-9_-]{40,}$/);
  assert.match(await mcp.hashReadToken(token), /^[a-f0-9]{64}$/);
  assert.equal(mcp.readBearerToken("Bearer header.payload.signature"), null);
  assert.equal(mcp.readBearerToken("Bearer calorie_read_wrong_scope"), null);
  assert.equal(mcp.readBearerToken("session=setline_read_cookie"), null);
});

test("history filtering preserves newest-first records and exact bounds", () => {
  const first = {
    id: "first",
    workoutId: "upper",
    workoutName: "Upper",
    completedAt: Date.parse("2026-08-02T12:00:00Z"),
    executions: [{ step: { exercise: "Bench press" } }],
  };
  const second = {
    ...first,
    id: "second",
    workoutId: "lower",
    workoutName: "Lower",
    completedAt: Date.parse("2026-08-03T12:00:00Z"),
    executions: [{ step: { exercise: "Romanian deadlift" } }],
  };
  const url = new URL(
    "https://setline.example/api/mcp/history?start=2026-08-01&end=2026-08-03&workout=lower&exercise=deadlift",
  );
  assert.deepEqual(
    mcp.filterHistory([first, second], url).map((entry) => entry.id),
    ["second"],
  );
});

test("MCP reads reject mutations and missing PATs before loading state", async () => {
  const env = { DB: { prepare: () => assert.fail("database should not be read") } };
  const mutation = await mcp.handleMcpRead(
    new Request("https://setline.example/api/mcp/history", { method: "POST" }),
    env,
  );
  assert.equal(mutation.status, 405);

  const anonymous = await mcp.handleMcpRead(
    new Request("https://setline.example/api/mcp/history"),
    env,
  );
  assert.equal(anonymous.status, 401);
});

test("active tokens bind every private read to the resolved owner", async () => {
  const calls = [];
  const env = {
    DB: {
      prepare(sql) {
        return {
          bind(...args) {
            calls.push({ sql, args });
            return {
              first: async () =>
                sql.includes("FROM mcp_read_tokens") ? { user_id: "owner-a" } : null,
            };
          },
        };
      },
    },
  };
  const response = await mcp.handleMcpRead(
    new Request("https://setline.example/api/mcp/history?limit=500&offset=0", {
      headers: { Authorization: `Bearer ${mcp.createReadToken()}` },
    }),
    env,
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  assert.deepEqual(body.items, []);
  assert.equal(body.page.limit, 100);
  assert.equal(body.page.nextOffset, null);
  const stateRead = calls.find((call) => call.sql.includes("FROM workout_state"));
  assert.deepEqual(stateRead?.args, ["owner-a"]);
});

test("revoked tokens fail before private state is read", async () => {
  const calls = [];
  const env = {
    DB: {
      prepare(sql) {
        calls.push(sql);
        return { bind: () => ({ first: async () => null }) };
      },
    },
  };
  const response = await mcp.handleMcpRead(
    new Request("https://setline.example/api/mcp/history", {
      headers: { Authorization: `Bearer ${mcp.createReadToken()}` },
    }),
    env,
  );

  assert.equal(response.status, 401);
  assert.equal(calls.some((sql) => sql.includes("FROM workout_state")), false);
});
