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

test("browser state is cleared only after confirmed account deletion", async () => {
  const [authClient, page] = await Promise.all([
    readFile(new URL("../app/lib/auth-client.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
  ]);

  const deleteHelper = authClient.slice(
    authClient.indexOf("export async function deleteSetlineAccount"),
    authClient.indexOf("export function clearDeletedAccountBrowserStorage"),
  );
  assert.match(deleteHelper, /fetch\("\/api\/auth\/delete-user"/);
  assert.match(deleteHelper, /body\?\.success !== true/);
  assert.doesNotMatch(deleteHelper, /localStorage\.removeItem/);

  const handler = page.slice(
    page.indexOf("const deleteAccount = async"),
    page.indexOf("const navigate ="),
  );
  assert.ok(
    handler.indexOf("await deleteSetlineAccount()") <
      handler.indexOf("clearDeletedAccountBrowserStorage"),
  );
  assert.match(
    handler,
    /clearDeletedAccountBrowserStorage\(\[\s*PENDING_SYNC_KEY,\s*STORAGE_KEY/,
  );
  assert.ok(
    handler.indexOf("return;") <
      handler.indexOf("clearDeletedAccountBrowserStorage"),
  );
  assert.match(handler, /setAccountState\(\{ status: "anonymous" \}\)/);
});

test("account deletion requires an explicit accessible confirmation", async () => {
  const [page, privacy] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(
      new URL("../app/components/LegalPage.tsx", import.meta.url),
      "utf8",
    ),
  ]);

  assert.match(page, /Delete account and cloud data/);
  assert.match(page, /aria-expanded=\{deleteConfirmationOpen\}/);
  assert.match(page, /aria-label="Account deletion confirmation"/);
  assert.match(page, /Delete permanently/);
  assert.match(page, /This browser copy was kept/);
  assert.match(page, /headingRef\.current\?\.focus\(\)/);
  assert.match(privacy, /permanently delete their Setline account/);
  assert.match(privacy, /does not revoke Setline access in\s+Google/);
});
