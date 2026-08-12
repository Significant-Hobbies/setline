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

test("server-renders the Setline restoration shell and public legal pages", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Setline — Workout execution tracker<\/title>/i);
  assert.match(html, /ACCOUNT OR DEVICE · YOUR CALL/);
  assert.match(html, /Keep the plan close\./);
  assert.doesNotMatch(
    html,
    /Your site is taking shape|codex-preview|react-loading-skeleton/i,
  );

  const [privacy, terms] = await Promise.all([
    render("/privacy"),
    render("/terms"),
  ]);
  assert.equal(privacy.status, 200);
  assert.equal(terms.status, 200);
  assert.match(await privacy.text(), /Privacy notice/);
  assert.match(await terms.text(), /Terms of use/);
});

test("serves public agent discovery before the private application routes", async () => {
  const [llms, catalog, markdown] = await Promise.all([
    render("/llms.txt"),
    render("/api/ai"),
    render("/index.md"),
  ]);
  assert.equal(llms.status, 200);
  assert.match(llms.headers.get("content-type") ?? "", /text\/plain/i);
  assert.match(await llms.text(), /^# Setline/);
  assert.equal(catalog.status, 200);
  assert.deepEqual((await catalog.json()).name, "Setline");
  assert.equal(markdown.status, 200);
  assert.match(markdown.headers.get("content-type") ?? "", /text\/markdown/i);
});

test("ships the installable offline shell and local workout state", async () => {
  const [
    manifest,
    serviceWorker,
    page,
    customProgrammePlanner,
    customWorkoutManager,
    customProgramme,
    workoutState,
    programme,
    progression,
    authSchema,
  ] = await Promise.all([
    readFile(new URL("../app/manifest.ts", import.meta.url), "utf8"),
    readFile(new URL("../public/sw.js", import.meta.url), "utf8"),
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(
      new URL("../app/components/CustomProgrammePlanner.tsx", import.meta.url),
      "utf8",
    ),
    readFile(
      new URL("../app/components/CustomWorkoutManager.tsx", import.meta.url),
      "utf8",
    ),
    readFile(
      new URL("../app/lib/custom-programme.ts", import.meta.url),
      "utf8",
    ),
    readFile(new URL("../app/lib/workout-state.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/programme.ts", import.meta.url), "utf8"),
    readFile(new URL("../app/lib/progression.ts", import.meta.url), "utf8"),
    readFile(new URL("../worker/schema.ts", import.meta.url), "utf8"),
  ]);

  assert.match(manifest, /display:\s*"standalone"/);
  assert.match(manifest, /icon-192\.png/);
  assert.match(serviceWorker, /setline-shell-v4/);
  assert.match(serviceWorker, /caches\.match/);
  assert.match(serviceWorker, /url\.pathname\.startsWith\("\/api\/"\)/);
  assert.match(workoutState, /setline:v1/);
  assert.match(workoutState, /restEndsAt/);
  assert.match(workoutState, /version:\s*6/);
  assert.match(workoutState, /customWorkouts/);
  assert.match(workoutState, /customProgramme/);
  assert.match(workoutState, /legacy-upper-a/);
  assert.match(workoutState, /actualDurationSeconds/);
  assert.match(programme, /27 Jul 2026/);
  assert.match(programme, /PROGRAMME_SCHEDULE/);
  assert.match(programme, /hard-cardio/);
  assert.match(
    authSchema,
    /expiresAt:\s*integer\("expiresAt",\s*\{\s*mode:\s*"timestamp"\s*\}\)\.notNull\(\)/,
  );
  assert.match(page, /localStorage/);
  assert.match(page, /PLAN \+ ACTUAL SESSION QUEUE/);
  assert.match(page, /CORRECT RECORDED STEP/);
  assert.match(page, /Save correction/);
  assert.match(page, /min:sec/);
  assert.match(page, /className="rail-edit"/);
  assert.match(workoutState, /quality:\s*null/);
  assert.match(page, /insertExtraExecution/);
  assert.match(page, /deferActiveExecution/);
  assert.match(page, /startQueuedExecution/);
  assert.match(page, /Download Setline backup/);
  assert.match(page, /Restore from backup/);
  assert.match(page, /Replace with this backup/);
  assert.match(page, /PROGRESSION AVAILABLE/);
  assert.match(page, /Keep current/);
  assert.match(progression, /suggestedWeight:\s*step\.targetWeight \+ 2\.5/);
  assert.match(progression, /latestComparable\.executions\.length < 2/);
  assert.match(page, /CustomWorkoutManager/);
  assert.match(page, /CustomProgrammePlanner/);
  assert.match(page, /customWorkouts=\{workoutState\.customWorkouts\}/);
  assert.match(page, /Discard unsaved authoring changes and leave Programme/);
  assert.match(
    page,
    /Discard unsaved authoring changes and start this workout/,
  );
  assert.match(page, /Today is unplanned/);
  assert.match(page, /removeProgrammeWorkoutAssignments/);
  assert.match(
    customWorkoutManager,
    /Discard this unsaved custom workout draft/,
  );
  assert.match(
    customWorkoutManager,
    /Discard the current unsaved draft and open another/,
  );
  assert.match(customWorkoutManager, /Remove .* from the unsaved draft/);
  assert.match(customWorkoutManager, /returnFocusRef/);
  assert.match(customWorkoutManager, /role="group"/);
  assert.match(customWorkoutManager, /Moved .* to step/);
  assert.match(customProgrammePlanner, /Starts Monday/);
  assert.match(
    customProgrammePlanner,
    /Repeat Week \{activeWeek\} through Week/,
  );
  assert.match(customProgrammePlanner, /Discard this unsaved programme draft/);
  assert.match(customProgrammePlanner, /beforeunload/);
  assert.match(customProgrammePlanner, /Choose a Monday/);
  assert.match(customProgrammePlanner, /Previous week/);
  assert.match(customProgrammePlanner, /authoringLocked/);
  assert.match(customWorkoutManager, /authoringLocked/);
  assert.match(customProgramme, /MAX_CUSTOM_PROGRAMME_WEEKS = 16/);
  assert.match(customProgramme, /status: "unplanned"/);
  assert.match(page, /Current device/);
  assert.match(page, /role="status"/);
  assert.match(page, /role="alert"/);
  assert.match(page, /hidden\s+type="file"/);

  await Promise.all([
    access(new URL("../public/icon-192.png", import.meta.url)),
    access(new URL("../public/icon-512.png", import.meta.url)),
    access(new URL("../public/favicon.png", import.meta.url)),
  ]);
});
