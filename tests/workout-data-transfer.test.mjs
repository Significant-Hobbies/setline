import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";
import { resolveWorkout } from "../src/lib/programme.ts";

let transfer;
let workoutState;
let customWorkouts;
let vite;

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  transfer = await vite.ssrLoadModule("/src/lib/workout-data-transfer.ts");
  workoutState = await vite.ssrLoadModule("/src/lib/workout-state.ts");
  customWorkouts = await vite.ssrLoadModule("/src/lib/custom-workouts.ts");
});

test.after(async () => {
  await vite.close();
});

test("exports a dated, non-sensitive Setline workout envelope", () => {
  const state = workoutState.emptyStoredState();
  const exportedAt = new Date("2026-07-31T03:00:00.000Z");
  const result = transfer.serializeWorkoutData(state, exportedAt);
  const parsed = JSON.parse(result.json);

  assert.equal(result.fileName, "setline-workout-data-2026-07-31.json");
  assert.deepEqual(parsed, {
    format: "setline-workout-data",
    formatVersion: 1,
    exportedAt: exportedAt.toISOString(),
    state,
  });
  assert.doesNotMatch(result.json, /account|cookie|credential|oauth/i);
});

test("validates metadata before reading an import file", () => {
  assert.equal(
    transfer.validateWorkoutDataFileMetadata({
      name: "workout.txt",
      size: 100,
      type: "text/plain",
    }),
    "Choose a Setline .json file.",
  );
  assert.equal(
    transfer.validateWorkoutDataFileMetadata({
      name: "workout.json",
      size: 100,
      type: "application/octet-stream",
    }),
    "Choose a JSON file exported by Setline.",
  );
  assert.equal(
    transfer.validateWorkoutDataFileMetadata({
      name: "workout.json",
      size: 0,
      type: "application/json",
    }),
    "The selected file is empty.",
  );
  assert.equal(
    transfer.validateWorkoutDataFileMetadata({
      name: "workout.json",
      size: transfer.MAX_WORKOUT_DATA_FILE_BYTES + 1,
      type: "application/json",
    }),
    "The selected file is larger than Setline’s 2 MiB import limit.",
  );
  assert.equal(
    transfer.validateWorkoutDataFileMetadata({
      name: "workout.JSON",
      size: 100,
      type: "",
    }),
    null,
  );
});

test("previews a valid active session without mutating the export", () => {
  const session = workoutState.makeWorkoutSession(
    resolveWorkout("upper", 1, 0),
    1,
    0,
    1_000,
  );
  session.records[0].status = "completed";
  const state = {
    version: 4,
    updatedAt: 2_000,
    session,
    history: [],
  };
  const raw = transfer.serializeWorkoutData(
    state,
    new Date("2026-07-31T03:00:00.000Z"),
  ).json;
  const before = structuredClone(state);
  const result = transfer.parseWorkoutDataImport(raw, 5_000);

  assert.equal(result.status, "ok");
  assert.deepEqual(state, before);
  assert.deepEqual(result.preview.activeSession, {
    workoutId: "upper",
    workoutName: "Upper",
    weekNumber: 1,
    phase: "active",
    completedExecutions: 1,
    totalExecutions: session.records.length,
  });
  assert.equal(result.preview.historyCount, 0);
  assert.equal(result.preview.customWorkoutCount, 0);
  assert.equal(result.preview.customProgramme, null);
  assert.equal(result.preview.latestWorkout, null);
});

test("round-trips custom templates and previews their programme", () => {
  const custom = customWorkouts.duplicateWorkoutTemplate(
    resolveWorkout("lower", 1, 2),
    "custom:backup",
    1_000,
  );
  const state = {
    ...workoutState.emptyStoredState(),
    updatedAt: 2_000,
    customWorkouts: [custom],
    customProgramme: {
      name: "Strength block",
      startsOn: "2026-07-27",
      weekCount: 4,
      enabled: true,
      assignments: [{ weekNumber: 1, dayIndex: 2, workoutId: custom.id }],
      createdAt: 1_000,
      updatedAt: 2_000,
    },
  };
  const raw = transfer.serializeWorkoutData(
    state,
    new Date("2026-07-31T03:00:00.000Z"),
  ).json;
  const result = transfer.parseWorkoutDataImport(raw, 5_000);

  assert.equal(result.status, "ok");
  assert.equal(result.preview.customWorkoutCount, 1);
  assert.deepEqual(result.preview.customProgramme, {
    name: "Strength block",
    enabled: true,
    startsOn: "2026-07-27",
    weekCount: 4,
    assignmentCount: 1,
  });
  assert.deepEqual(result.preview.state.customWorkouts, [
    JSON.parse(JSON.stringify(custom)),
  ]);
});

test("rejects a programme with a dangling custom-workout assignment", () => {
  const state = {
    ...workoutState.emptyStoredState(),
    customProgramme: {
      name: "Broken block",
      startsOn: "2026-07-27",
      weekCount: 1,
      enabled: true,
      assignments: [
        { weekNumber: 1, dayIndex: 0, workoutId: "custom:missing" },
      ],
      createdAt: 1_000,
      updatedAt: 1_000,
    },
  };
  const raw = JSON.stringify(
    transfer.createWorkoutDataEnvelope(
      state,
      new Date("2026-07-31T03:00:00.000Z"),
    ),
  );
  assert.equal(
    transfer.parseWorkoutDataImport(raw).message,
    "This Setline export contains invalid workout data or exercise order.",
  );
});

test("rejects malformed, unknown, and invalid workout exports", () => {
  assert.deepEqual(transfer.parseWorkoutDataImport("{"), {
    status: "error",
    message: "This file is not valid JSON.",
  });
  assert.deepEqual(transfer.parseWorkoutDataImport("{}"), {
    status: "error",
    message: "This file has an unsupported Setline transfer shape.",
  });

  const state = workoutState.emptyStoredState();
  const envelope = transfer.createWorkoutDataEnvelope(
    state,
    new Date("2026-07-31T03:00:00.000Z"),
  );
  assert.equal(
    transfer.parseWorkoutDataImport(
      JSON.stringify({ ...envelope, formatVersion: 2 }),
    ).message,
    "This Setline export version is not supported.",
  );
  assert.equal(
    transfer.parseWorkoutDataImport(
      JSON.stringify({ ...envelope, exportedAt: "yesterday" }),
    ).message,
    "This Setline export has an invalid export time.",
  );
  assert.equal(
    transfer.parseWorkoutDataImport(
      JSON.stringify({
        ...envelope,
        state: { ...state, history: "not-history" },
      }),
    ).message,
    "This Setline export contains invalid workout data or exercise order.",
  );
});

test("migrates a supported legacy state inside the transfer envelope", () => {
  const legacyState = {
    version: 1,
    session: null,
    history: [],
  };
  const result = transfer.parseWorkoutDataImport(
    JSON.stringify({
      format: "setline-workout-data",
      formatVersion: 1,
      exportedAt: "2026-07-31T03:00:00.000Z",
      state: legacyState,
    }),
    7_000,
  );

  assert.equal(result.status, "ok");
  assert.equal(result.preview.state.version, 6);
  assert.deepEqual(result.preview.state.customWorkouts, []);
  assert.equal(result.preview.state.customProgramme, null);
  assert.equal(result.preview.state.updatedAt, 7_000);
});

test("activates an import as a new local mutation", () => {
  const imported = {
    ...workoutState.emptyStoredState(),
    updatedAt: 10,
  };
  const current = {
    ...workoutState.emptyStoredState(),
    updatedAt: 20,
  };

  assert.equal(
    transfer.activateImportedWorkoutData(imported, current, 15).updatedAt,
    21,
  );
  assert.equal(
    transfer.activateImportedWorkoutData(imported, current, 30).updatedAt,
    30,
  );
});
