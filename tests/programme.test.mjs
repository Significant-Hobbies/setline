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
    assert.equal(migrated?.version, 4);
    assert.equal(migrated?.updatedAt, 42);
    assert.equal(migrated?.session?.workoutId, "legacy-upper-a");
    assert.deepEqual(
      migrated?.session?.records.map((record) => record.step.plannedStepId),
      LEGACY_UPPER_STEPS.map((planned) => planned.id),
    );
    assert.deepEqual(
      migrated?.session?.queue,
      LEGACY_UPPER_STEPS.map((planned) => `planned:${planned.id}`),
    );
    assert.ok(
      migrated?.session?.records.every(
        (record) => record.segments[0].durationSeconds === null,
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

test("records flexible execution without mutating the authored workout", async () => {
  const vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  try {
    const {
      deferActiveExecution,
      executionIsModified,
      executionIsValid,
      executionVolume,
      getExecution,
      getSessionMetrics,
      insertExtraExecution,
      makeWorkoutSession,
      parseStoredState,
      startQueuedExecution,
    } = await vite.ssrLoadModule("/app/lib/workout-state.ts");
    const template = resolveWorkout("upper", 1, 0);
    const authoredIds = template.steps.map((step) => step.id);
    const session = makeWorkoutSession(template, 1, 0, 1_000);

    assert.deepEqual(
      session.records.map((record) => record.step.plannedStepId),
      authoredIds,
    );
    assert.deepEqual(
      session.queue,
      authoredIds.map((id) => `planned:${id}`),
    );

    const working = session.records.find(
      (record) =>
        record.step.setType === "Working" &&
        record.step.tracking === "weight-reps",
    );
    assert.ok(working);
    working.status = "completed";
    working.segments = [
      {
        id: `${working.id}:segment:1`,
        weight: 60,
        reps: 5,
        durationSeconds: null,
      },
      {
        id: `${working.id}:segment:2`,
        weight: 50,
        reps: 3,
        durationSeconds: null,
      },
    ];
    assert.equal(executionIsValid(working), true);
    assert.equal(executionIsModified(working), true);
    assert.equal(executionVolume(working), 450);

    const partial = structuredClone(working);
    partial.segments = [
      {
        id: `${partial.id}:segment:partial`,
        weight: partial.step.targetWeight,
        reps: Math.max(1, (partial.step.targetReps ?? 2) - 1),
        durationSeconds: null,
      },
    ];
    assert.equal(executionIsValid(partial), true);
    assert.equal(executionIsModified(partial), true);

    const source = session.records[0];
    const withExtra = insertExtraExecution(
      session,
      source,
      "extra:test-execution",
    );
    assert.equal(template.steps.length, authoredIds.length);
    assert.equal(withExtra.queue[1], "extra:test-execution");
    assert.equal(withExtra.records.at(-1).source, "extra");
    assert.equal(withExtra.records.at(-1).clonedFromId, source.id);
    assert.equal(withExtra.records.at(-1).plannedPosition, null);

    const deferred = deferActiveExecution(session, 1_500);
    assert.equal(deferred.queue.at(-1), session.queue[0]);
    assert.equal(getExecution(deferred, session.queue[0]).deferred, true);
    assert.equal(
      getExecution(deferred, deferred.queue[0]).startedAt,
      1_500,
    );
    assert.deepEqual(
      session.records.map((record) => record.step.plannedStepId),
      authoredIds,
    );

    const priorId = session.queue[0];
    const nextId = session.queue[1];
    const resting = {
      ...session,
      phase: "rest",
      activeIndex: 1,
      restFromExecutionId: priorId,
      authoredRestSeconds: 60,
      adjustedRestSeconds: 90,
      records: session.records.map((record) =>
        record.id === priorId
          ? {
              ...record,
              status: "completed",
              completedAt: 10_000,
              authoredRestSeconds: 60,
              adjustedRestSeconds: 90,
            }
          : record,
      ),
    };
    const resumed = startQueuedExecution(resting, 12_400);
    assert.equal(getExecution(resumed, priorId).actualRestSeconds, 2);
    assert.equal(getExecution(resumed, priorId).authoredRestSeconds, 60);
    assert.equal(getExecution(resumed, priorId).adjustedRestSeconds, 90);
    assert.equal(getExecution(resumed, nextId).startedAt, 12_400);

    const metrics = getSessionMetrics({
      ...session,
      records: session.records.map((record) =>
        record.id === working.id ? working : record,
      ),
    });
    assert.equal(metrics.workingVolume, 450);
    assert.equal(metrics.modifiedSets, 1);

    const historyEntry = {
      id: "history-flexible",
      workoutId: session.workoutId,
      workoutName: session.workoutName,
      weekNumber: session.weekNumber,
      completedAt: 20_000,
      durationSeconds: 19,
      completedSets: 1,
      modifiedSets: 1,
      extraSets: 0,
      deferredSets: 0,
      skippedSets: 0,
      workingVolume: 450,
      warmupVolume: 0,
      completedDurationSeconds: 0,
      totalActualRestSeconds: 2,
      averageRpe: null,
      quality: null,
      detailsAvailable: true,
      executions: [
        {
          ...working,
          plannedPosition: working.plannedPosition,
          performedPosition: 1,
          startedAt: 15_000,
          completedAt: 16_000,
          actualRestSeconds: 2,
        },
      ],
    };
    const persisted = parseStoredState({
      version: 4,
      updatedAt: 21_000,
      session: null,
      history: [historyEntry],
    });
    assert.equal(persisted?.history[0].executions[0].segments.length, 2);
    assert.equal(
      executionVolume(persisted?.history[0].executions[0]),
      450,
    );

    const legacyHistory = parseStoredState({
      version: 3,
      updatedAt: 22_000,
      session: null,
      history: [
        {
          id: "summary-only",
          workoutId: "upper",
          workoutName: "Upper",
          weekNumber: 1,
          completedAt: 20_000,
          durationSeconds: 3_600,
          completedSets: 12,
          skippedSets: 1,
          workingVolume: 4_000,
          warmupVolume: 800,
          completedDurationSeconds: 300,
          averageRpe: 7.5,
          quality: 4,
        },
      ],
    });
    assert.equal(legacyHistory?.version, 4);
    assert.equal(legacyHistory?.history[0].detailsAvailable, false);
    assert.deepEqual(legacyHistory?.history[0].executions, []);
  } finally {
    await vite.close();
  }
});
