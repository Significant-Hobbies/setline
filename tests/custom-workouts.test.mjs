import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";

import { resolveWorkout } from "../app/lib/programme.ts";

let customWorkouts;
let workoutState;
let vite;

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  customWorkouts = await vite.ssrLoadModule("/app/lib/custom-workouts.ts");
  workoutState = await vite.ssrLoadModule("/app/lib/workout-state.ts");
});

test.after(async () => {
  await vite.close();
});

test("duplicates a bundled workout as an independent custom template", () => {
  const source = resolveWorkout("upper", 1, 0);
  const sourceBefore = structuredClone(source);
  const duplicate = customWorkouts.duplicateWorkoutTemplate(
    source,
    "custom:upper-copy",
    1_000,
  );

  assert.equal(customWorkouts.isCustomWorkoutTemplate(duplicate), true);
  assert.equal(duplicate.name, "Upper copy");
  assert.equal(duplicate.steps.length, source.steps.length);
  assert.equal(new Set(duplicate.steps.map((step) => step.id)).size, duplicate.steps.length);
  assert.ok(duplicate.steps.every((step) => step.id.startsWith("custom:upper-copy:step:")));

  duplicate.steps[0].exercise = "Changed only in the copy";
  assert.deepEqual(source, sourceBefore);
});

test("rejects empty, reordered-id, unbounded, and modality-invalid templates", () => {
  const valid = customWorkouts.duplicateWorkoutTemplate(
    resolveWorkout("mobility", 1, 4),
    "custom:mobility-copy",
    2_000,
  );
  assert.equal(customWorkouts.isCustomWorkoutTemplate(valid), true);

  assert.equal(
    customWorkouts.isCustomWorkoutTemplate({ ...valid, name: " " }),
    false,
  );
  assert.equal(
    customWorkouts.isCustomWorkoutTemplate({
      ...valid,
      steps: Array.from({ length: 101 }, () => valid.steps[0]),
    }),
    false,
  );
  assert.equal(
    customWorkouts.isCustomWorkoutTemplate({
      ...valid,
      steps: [
        {
          ...valid.steps[0],
          tracking: "duration",
          targetDurationSeconds: null,
        },
      ],
    }),
    false,
  );
});

test("migrates version 4 state and round-trips valid version 6 templates", () => {
  const versionFour = {
    version: 4,
    updatedAt: 42,
    session: null,
    history: [],
  };
  const migrated = workoutState.parseStoredState(versionFour, 99);
  assert.deepEqual(migrated, {
    version: 6,
    updatedAt: 42,
    session: null,
    history: [],
    customWorkouts: [],
    customProgramme: null,
  });

  const custom = customWorkouts.duplicateWorkoutTemplate(
    resolveWorkout("lower", 1, 1),
    "custom:lower-copy",
    3_000,
  );
  const parsed = workoutState.parseStoredState({
    ...workoutState.emptyStoredState(),
    updatedAt: 3_001,
    customWorkouts: [custom],
  });
  assert.deepEqual(parsed?.customWorkouts, [custom]);

  assert.equal(
    workoutState.parseStoredState({
      ...workoutState.emptyStoredState(),
      customWorkouts: [custom, custom],
    }),
    null,
  );
});

test("custom sessions retain snapshots after their template changes or disappears", () => {
  const custom = customWorkouts.duplicateWorkoutTemplate(
    resolveWorkout("mobility", 1, 4),
    "custom:snapshot",
    4_000,
  );
  const session = workoutState.makeWorkoutSession(custom, 1, 0, 5_000);
  const authoredExercises = session.records.map((record) => record.step.exercise);

  custom.steps[0].exercise = "Edited after start";
  assert.deepEqual(
    session.records.map((record) => record.step.exercise),
    authoredExercises,
  );

  const parsedWithoutTemplate = workoutState.parseStoredState({
    ...workoutState.emptyStoredState(),
    updatedAt: 5_001,
    session,
    customWorkouts: [],
  });
  assert.deepEqual(
    parsedWithoutTemplate?.session?.records.map((record) => record.step.exercise),
    authoredExercises,
  );
});
