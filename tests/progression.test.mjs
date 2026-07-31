import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";

let progression;
let vite;

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  progression = await vite.ssrLoadModule("/app/lib/progression.ts");
});

test.after(async () => {
  await vite.close();
});

const currentStep = {
  id: "bench-working-1",
  plannedStepId: "bench-working-1",
  exercise: "Bench press",
  setType: "Working",
  setLabel: "Working set 1 of 3",
  tracking: "weight-reps",
  targetWeight: 65,
  targetReps: 5,
  targetRepsMax: 8,
  targetDurationSeconds: null,
  restSeconds: 180,
  targetRpe: 8,
  cue: "Repeat the same touch point.",
  optional: false,
};

function execution({
  id,
  weight = 65,
  reps = 8,
  rpe = 8,
  source = "planned",
  status = "completed",
  segments = 1,
  setType = "Working",
  tracking = "weight-reps",
  exercise = "Bench press",
}) {
  return {
    id,
    source,
    status,
    actualRpe: rpe,
    step: {
      ...currentStep,
      id,
      plannedStepId: source === "planned" ? id : null,
      exercise,
      setType,
      tracking,
    },
    segments: Array.from({ length: segments }, (_, index) => ({
      id: `${id}:segment:${index + 1}`,
      weight,
      reps,
      durationSeconds: null,
    })),
  };
}

function historyEntry(id, completedAt, executions) {
  return {
    id,
    workoutName: `Workout ${id}`,
    completedAt,
    executions,
  };
}

test("recommends 2.5 kilograms after every comparable set clears the range and RPE", () => {
  const recommendation = progression.getProgressionRecommendation(currentStep, [
    historyEntry("latest", 2_000, [
      execution({ id: "set-1" }),
      execution({ id: "set-2", rpe: 7.5 }),
      execution({ id: "set-3", reps: 9 }),
    ]),
  ]);

  assert.deepEqual(recommendation, {
    sourceHistoryId: "latest",
    sourceWorkoutName: "Workout latest",
    sourceCompletedAt: 2_000,
    evidenceSetCount: 3,
    previousWeight: 65,
    repetitionThreshold: 8,
    rpeCeiling: 8,
    suggestedWeight: 67.5,
    suggestedReps: 5,
  });
});

test("uses only the newest comparable session and returns no recommendation after a miss", () => {
  const recommendation = progression.getProgressionRecommendation(currentStep, [
    historyEntry("older-pass", 1_000, [
      execution({ id: "old-1" }),
      execution({ id: "old-2" }),
    ]),
    historyEntry("newer-miss", 3_000, [
      execution({ id: "new-1" }),
      execution({ id: "new-2", reps: 7 }),
    ]),
  ]);

  assert.equal(recommendation, null);
});

test("excludes extra, multi-segment, warm-up, and different-exercise executions", () => {
  const recommendation = progression.getProgressionRecommendation(currentStep, [
    historyEntry("latest", 2_000, [
      execution({ id: "pass-1" }),
      execution({ id: "pass-2" }),
      execution({ id: "extra", source: "extra", reps: 1, rpe: 10 }),
      execution({ id: "drop", segments: 2, reps: 1, rpe: 10 }),
      execution({ id: "warm-up", setType: "Warm-up", reps: 1, rpe: 10 }),
      execution({ id: "row", exercise: "Cable row", reps: 1, rpe: 10 }),
    ]),
  ]);

  assert.equal(recommendation?.evidenceSetCount, 2);
  assert.equal(recommendation?.suggestedWeight, 67.5);
});

test("requires at least two passing sets with matching load, top reps, and recorded RPE", () => {
  const cases = [
    [execution({ id: "only-one" })],
    [execution({ id: "set-1" }), execution({ id: "set-2", weight: 62.5 })],
    [execution({ id: "set-1" }), execution({ id: "set-2", reps: 7 })],
    [execution({ id: "set-1" }), execution({ id: "set-2", rpe: null })],
    [execution({ id: "set-1" }), execution({ id: "set-2", rpe: 8.5 })],
  ];

  for (const [index, executions] of cases.entries()) {
    assert.equal(
      progression.getProgressionRecommendation(currentStep, [
        historyEntry(`case-${index}`, 2_000, executions),
      ]),
      null,
    );
  }
});

test("returns no recommendation for unsupported current steps", () => {
  const passingHistory = [
    historyEntry("latest", 2_000, [
      execution({ id: "set-1" }),
      execution({ id: "set-2" }),
    ]),
  ];
  const unsupported = [
    { ...currentStep, setType: "Warm-up" },
    { ...currentStep, tracking: "reps", targetWeight: null },
    { ...currentStep, targetWeight: null },
    { ...currentStep, targetRepsMax: null },
    { ...currentStep, targetRepsMax: 5 },
    { ...currentStep, targetRpe: undefined },
  ];

  for (const step of unsupported) {
    assert.equal(
      progression.getProgressionRecommendation(step, passingHistory),
      null,
    );
  }
});

test("applies accepted or edited values to the current actuals without changing the authored step", () => {
  const record = execution({ id: "current", reps: 5 });
  record.status = "pending";
  const authoredStep = structuredClone(record.step);

  const accepted = progression.applyProgressionValues(record, 67.5, 5);
  const edited = progression.applyProgressionValues(record, 66, 6);

  assert.deepEqual(accepted.step, authoredStep);
  assert.deepEqual(edited.step, authoredStep);
  assert.equal(accepted.segments[0].weight, 67.5);
  assert.equal(accepted.segments[0].reps, 5);
  assert.equal(edited.segments[0].weight, 66);
  assert.equal(edited.segments[0].reps, 6);
  assert.equal(record.segments[0].weight, 65);
  assert.equal(record.segments[0].reps, 5);
});
