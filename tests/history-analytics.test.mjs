import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";

let analytics;
let vite;

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  analytics = await vite.ssrLoadModule("/src/lib/history-analytics.ts");
});

test.after(async () => {
  await vite.close();
});

function execution({
  id,
  exercise = "Bench Press",
  setType = "Working",
  tracking = "weight-reps",
  weight = 60,
  reps = 8,
  durationSeconds = null,
  status = "completed",
  actualRpe = 8,
}) {
  return {
    id,
    source: "planned",
    clonedFromId: null,
    plannedPosition: 1,
    performedPosition: 1,
    deferred: false,
    status,
    step: {
      id,
      plannedStepId: id,
      exercise,
      setType,
      setLabel: "Set 1",
      tracking,
      targetWeight: weight,
      targetReps: reps,
      targetRepsMax: reps,
      targetDurationSeconds: durationSeconds,
      restSeconds: 60,
      targetRpe: 8,
      cue: "",
      optional: false,
    },
    segments: [
      {
        id: `${id}:segment:1`,
        weight,
        reps,
        durationSeconds,
      },
    ],
    actualRpe,
    startedAt: 1,
    completedAt: 2,
    authoredRestSeconds: 60,
    adjustedRestSeconds: 60,
    actualRestSeconds: 55,
  };
}

function historyEntry({
  id,
  completedAt,
  workoutId = "upper",
  workoutName = "Upper",
  weekNumber = 1,
  detailsAvailable = true,
  executions = [],
  durationSeconds = 1_800,
  workingVolume = 0,
  completedSets = executions.filter((record) => record.status === "completed")
    .length,
  modifiedSets = 0,
  skippedSets = executions.filter((record) => record.status === "skipped")
    .length,
}) {
  return {
    id,
    workoutId,
    workoutName,
    weekNumber,
    completedAt,
    durationSeconds,
    completedSets,
    modifiedSets,
    extraSets: 0,
    deferredSets: 0,
    skippedSets,
    workingVolume,
    warmupVolume: 0,
    completedDurationSeconds: 0,
    totalActualRestSeconds: 0,
    averageRpe: null,
    quality: null,
    detailsAvailable,
    executions,
  };
}

test("returns an honest empty analytics model", () => {
  assert.deepEqual(analytics.deriveHistoryAnalytics([]), {
    overview: {
      recordedSessions: 0,
      detailedSessions: 0,
      customSessions: 0,
      totalDurationSeconds: 0,
      totalWorkingVolume: 0,
      latestCompletedAt: null,
    },
    exercises: [],
    workouts: [],
    programmeWeeks: [],
  });
});

test("groups normalized exercise identity and calculates only recorded detail", () => {
  const older = historyEntry({
    id: "older",
    completedAt: 1_000,
    executions: [
      execution({
        id: "old-working",
        exercise: "  Bench   Press ",
        weight: 60,
      }),
    ],
    workingVolume: 480,
  });
  const newer = historyEntry({
    id: "newer",
    completedAt: 2_000,
    executions: [
      execution({
        id: "new-working",
        exercise: "Bench Press",
        weight: 65,
        reps: 5,
      }),
      execution({
        id: "new-warmup",
        exercise: "BENCH PRESS",
        setType: "Warm-up",
        weight: 30,
        reps: 10,
        actualRpe: null,
      }),
      execution({
        id: "row",
        exercise: "Cable row",
        weight: 50,
        reps: 10,
      }),
    ],
    workingVolume: 825,
  });

  const result = analytics.deriveHistoryAnalytics([newer, older]);
  const bench = result.exercises.find(
    (exercise) => exercise.id === "bench press",
  );

  assert.ok(bench);
  assert.equal(bench.name, "Bench Press");
  assert.equal(bench.recordedSessions, 2);
  assert.equal(bench.completedExecutions, 3);
  assert.equal(bench.bestWeight, 65);
  assert.equal(bench.repetitionsAtBestWeight, 5);
  assert.equal(bench.bestRepetitions, 10);
  assert.equal(bench.totalWorkingVolume, 805);
  assert.equal(bench.trendMetric, "weight");
  assert.deepEqual(
    bench.trend.map((point) => point.historyId),
    ["older", "newer"],
  );
  assert.equal(
    result.exercises.some((exercise) => exercise.id === "cable row"),
    true,
  );
});

test("uses summary-only records only where their fields can support analytics", () => {
  const legacy = historyEntry({
    id: "legacy",
    completedAt: 3_000,
    workoutName: "Original Upper",
    detailsAvailable: false,
    executions: [],
    durationSeconds: 2_400,
    workingVolume: 1_200,
    completedSets: 8,
    modifiedSets: 2,
    skippedSets: 1,
  });
  const result = analytics.deriveHistoryAnalytics([legacy]);

  assert.equal(result.overview.recordedSessions, 1);
  assert.equal(result.overview.detailedSessions, 0);
  assert.equal(result.overview.totalWorkingVolume, 1_200);
  assert.equal(result.exercises.length, 0);
  assert.equal(result.workouts[0].completedSets, 8);
  assert.equal(result.programmeWeeks[0].modifiedSets, 2);
});

test("uses the latest point that actually recorded the selected metric", () => {
  const result = analytics.deriveHistoryAnalytics([
    historyEntry({
      id: "weighted",
      completedAt: 1_000,
      executions: [execution({ id: "weighted-set", weight: 70, reps: 5 })],
    }),
    historyEntry({
      id: "reps-only",
      completedAt: 2_000,
      executions: [
        execution({
          id: "reps-only-set",
          tracking: "reps",
          weight: null,
          reps: 12,
        }),
      ],
    }),
  ]);

  const bench = result.exercises[0];
  assert.equal(bench.recordedSessions, 2);
  assert.equal(bench.trendMetric, "weight");
  assert.equal(bench.latest.historyId, "weighted");
  assert.deepEqual(
    bench.trend.map((point) => point.historyId),
    ["weighted"],
  );
});

test("groups workouts by stable id, keeps the newest name, and separates custom sessions", () => {
  const result = analytics.deriveHistoryAnalytics([
    historyEntry({
      id: "old-name",
      completedAt: 1_000,
      workoutName: "Upper A",
      durationSeconds: 1_200,
      workingVolume: 500,
    }),
    historyEntry({
      id: "new-name",
      completedAt: 2_000,
      workoutName: "Upper",
      durationSeconds: 1_800,
      workingVolume: 700,
      weekNumber: 2,
    }),
    historyEntry({
      id: "custom",
      completedAt: 3_000,
      workoutId: "custom:push",
      workoutName: "Push",
      weekNumber: 2,
    }),
  ]);

  const upper = result.workouts.find(
    (workout) => workout.workoutId === "upper",
  );
  assert.ok(upper);
  assert.equal(upper.workoutName, "Upper");
  assert.equal(upper.recordedSessions, 2);
  assert.equal(upper.averageDurationSeconds, 1_500);
  assert.equal(upper.totalWorkingVolume, 1_200);
  assert.equal(result.overview.customSessions, 1);
  assert.deepEqual(
    result.programmeWeeks.map((week) => week.weekNumber),
    [1, 2],
  );
  assert.equal(result.programmeWeeks[1].recordedSessions, 1);
});

test("bounds visible trends to the newest eight while retaining lifetime bests", () => {
  const history = Array.from({ length: 10 }, (_, index) =>
    historyEntry({
      id: `session-${index + 1}`,
      completedAt: index + 1,
      executions: [
        execution({
          id: `set-${index + 1}`,
          weight: index === 0 ? 100 : 50 + index,
          reps: 5,
        }),
      ],
    }),
  );

  const bench = analytics.deriveHistoryAnalytics(history).exercises[0];
  assert.equal(bench.recordedSessions, 10);
  assert.equal(bench.bestWeight, 100);
  assert.equal(bench.trend.length, 8);
  assert.deepEqual(
    bench.trend.map((point) => point.historyId),
    Array.from({ length: 8 }, (_, index) => `session-${index + 3}`),
  );
});
