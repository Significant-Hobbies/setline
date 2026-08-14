import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("account deletion uses Better Auth and the existing D1 ownership cascades", async () => {
  const [auth, migration] = await Promise.all([
    readFile(new URL("../worker/auth.ts", import.meta.url), "utf8"),
    readFile(
      new URL("../migrations/0001_auth_and_state.sql", import.meta.url),
      "utf8",
    ),
  ]);

  assert.match(auth, /user:\s*\{\s*deleteUser:\s*\{\s*enabled:\s*true/);
  for (const table of ["session", "account"]) {
    assert.match(
      migration,
      new RegExp(
        `CREATE TABLE ${table}[\\s\\S]*?userId TEXT NOT NULL REFERENCES user\\(id\\) ON DELETE CASCADE`,
      ),
    );
  }
  assert.match(
    migration,
    /CREATE TABLE workout_state[\s\S]*?user_id TEXT PRIMARY KEY NOT NULL REFERENCES user\(id\) ON DELETE CASCADE/,
  );
});
