import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";

import {
  getProgrammePosition,
  LEGACY_UPPER_STEPS,
  PROGRAMME_SCHEDULE,
  resolveWorkout,
} from "../app/lib/programme.ts";

test("resolves the dated block and all seven scheduled days", () => {
  assert.equal(PROGRAMME_SCHEDULE.length, 7);
  assert.deepEqual(
    PROGRAMME_SCHEDULE.map((entry) => entry.workoutId),
    [
      "upper",
      "lower",
      "easy-mobility",
      "upper-hard",
      "mobility",
      "lower",
      "easy-mobility",
    ],
  );

  const start = getProgrammePosition(new Date(2026, 6, 27, 12));
  assert.equal(start.weekNumber, 1);
  assert.equal(start.dayIndex, 0);
  assert.equal(start.workout.id, "upper");
  assert.equal(start.inBlock, true);

  const tuesday = getProgrammePosition(new Date(2026, 6, 28, 12));
  assert.equal(tuesday.weekNumber, 1);
  assert.equal(tuesday.workout.id, "lower");

  const end = getProgrammePosition(new Date(2026, 9, 18, 12));
  assert.equal(end.weekNumber, 12);
  assert.equal(end.dayIndex, 6);
  assert.equal(end.workout.id, "easy-mobility");
});

test("keeps the authored Upper exercise order", () => {
  const steps = resolveWorkout("upper", 1, 0).steps;
  const firstIndex = (name) => steps.findIndex((planned) => planned.exercise === name);

  assert.ok(firstIndex("Easy treadmill, bike or rower") < firstIndex("Bench press"));
  assert.ok(firstIndex("Bench press") < firstIndex("Lat pulldown"));
  assert.ok(firstIndex("Lat pulldown") < firstIndex("Machine or DB shoulder press"));
  assert.ok(
    firstIndex("Machine or DB shoulder press") <
      firstIndex("Chest-supported or cable row"),
  );
  assert.ok(firstIndex("Chest-supported or cable row") < firstIndex("Ab wheel from knees"));
  assert.ok(firstIndex("Ab wheel from knees") < firstIndex("Farmer carry"));
  assert.equal(
    steps.filter((planned) => planned.id.startsWith("upper-bench-working-")).length,
    3,
  );
  assert.deepEqual(
    steps.slice(4, 7).map((planned) => planned.targetWeight),
    [20, 40, 55],
  );
});

test("keeps the authored Lower order and week-aware RDL sets", () => {
  const weekOne = resolveWorkout("lower", 1, 1).steps;
  const weekThree = resolveWorkout("lower", 3, 1).steps;
  const firstIndex = (steps, name) =>
    steps.findIndex((planned) => planned.exercise === name);

  assert.ok(firstIndex(weekOne, "Hack squat or leg press") < firstIndex(weekOne, "Romanian deadlift"));
  assert.ok(firstIndex(weekOne, "Romanian deadlift") < firstIndex(weekOne, "Supported Bulgarian split squat"));
  assert.ok(firstIndex(weekOne, "Supported Bulgarian split squat") < firstIndex(weekOne, "Lying leg curl"));
  assert.ok(firstIndex(weekOne, "Lying leg curl") < firstIndex(weekOne, "Standing calf raise"));

  const rdlWorking = (steps) =>
    steps.filter((planned) => planned.id.startsWith("lower-rdl-working-"));
  assert.equal(rdlWorking(weekOne).length, 2);
  assert.equal(rdlWorking(weekThree).length, 3);
  assert.equal(rdlWorking(weekThree)[2].optional, true);
});

test("runs Upper before the correct number of Thursday hard intervals", () => {
  const weekOne = resolveWorkout("upper-hard", 1, 3).steps;
  const weekThree = resolveWorkout("upper-hard", 3, 3).steps;
  const hardRounds = (steps) =>
    steps.filter((planned) => /^hard-cardio-\d+$/.test(planned.id));

  assert.equal(hardRounds(weekOne).length, 4);
  assert.equal(hardRounds(weekThree).length, 5);
  assert.ok(
    weekOne.findIndex((planned) => planned.id === "upper-farmer-2") <
      weekOne.findIndex((planned) => planned.id === "hard-cardio-warmup"),
  );
});

test("all startable templates have stable unique ordered ids", () => {
  const trackingKinds = new Set();
  for (const schedule of PROGRAMME_SCHEDULE) {
    for (const week of [1, 3, 5, 9, 12]) {
      const workout = resolveWorkout(schedule.workoutId, week, schedule.dayIndex);
      const ids = workout.steps.map((planned) => planned.id);
      assert.equal(new Set(ids).size, ids.length, `${schedule.workoutId} week ${week}`);
      workout.steps.forEach((planned) => trackingKinds.add(planned.tracking));
    }
  }
  assert.deepEqual(
    [...trackingKinds].sort(),
    ["duration", "reps", "weight-duration", "weight-reps"],
  );
  assert.deepEqual(
    LEGACY_UPPER_STEPS.map((planned) => planned.id),
    [
      "bench-warmup-1",
      "bench-warmup-2",
      "bench-warmup-3",
      "bench-working-1",
      "bench-working-2",
      "bench-working-3",
      "pulldown-1",
      "pulldown-2",
      "pulldown-3",
      "row-1",
      "row-2",
      "row-3",
    ],
  );
});

test("migrates a version 2 session without changing its set order", async () => {
  const vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  try {
    const { parseStoredState } = await vite.ssrLoadModule(
      "/app/lib/workout-state.ts",
    );
    const records = LEGACY_UPPER_STEPS.map((planned) => ({
      setId: planned.id,
      status: "pending",
      actualWeight: planned.targetWeight ?? 0,
      actualReps: planned.targetReps ?? 0,
      actualRpe: null,
      completedAt: null,
    }));
    const legacy = {
      version: 2,
      updatedAt: 42,
      session: {
        id: "legacy-session",
        startedAt: 1,
        completedAt: null,
        phase: "active",
        activeIndex: 0,
        restEndsAt: null,
        pausedRestSeconds: null,
        plannedRestSeconds: 0,
        records,
        quality: null,
      },
      history: [],
    };

    const migrated = parseStoredState(legacy, 99);
    assert.equal(migrated?.version, 3);
    assert.equal(migrated?.updatedAt, 42);
    assert.equal(migrated?.session?.workoutId, "legacy-upper-a");
    assert.deepEqual(
      migrated?.session?.records.map((record) => record.setId),
      LEGACY_UPPER_STEPS.map((planned) => planned.id),
    );
    assert.ok(
      migrated?.session?.records.every(
        (record) => record.actualDurationSeconds === null,
      ),
    );

    const reordered = structuredClone(legacy);
    [reordered.session.records[0], reordered.session.records[1]] = [
      reordered.session.records[1],
      reordered.session.records[0],
    ];
    assert.equal(parseStoredState(reordered, 99), null);
  } finally {
    await vite.close();
  }
});
