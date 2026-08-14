import assert from "node:assert/strict";
import test from "node:test";
import { createServer } from "vite";

let customProgramme;
let customWorkouts;
let workoutState;
let vite;

const validWorkoutIds = new Set(["custom:upper", "custom:lower"]);
const baseProgramme = {
  name: "My strength block",
  startsOn: "2026-10-26",
  weekCount: 4,
  enabled: true,
  assignments: [
    { weekNumber: 1, dayIndex: 0, workoutId: "custom:upper" },
    { weekNumber: 1, dayIndex: 3, workoutId: "custom:lower" },
  ],
  createdAt: 1_000,
  updatedAt: 1_000,
};

test.before(async () => {
  vite = await createServer({
    appType: "custom",
    configFile: false,
    server: { middlewareMode: true },
  });
  customProgramme = await vite.ssrLoadModule("/src/lib/custom-programme.ts");
  customWorkouts = await vite.ssrLoadModule("/src/lib/custom-workouts.ts");
  workoutState = await vite.ssrLoadModule("/src/lib/workout-state.ts");
});

test.after(async () => {
  await vite.close();
});

test("accepts one bounded Monday-based programme", () => {
  assert.equal(
    customProgramme.isCustomProgramme(baseProgramme, validWorkoutIds),
    true,
  );
  assert.equal(
    customProgramme.isCustomProgramme(
      { ...baseProgramme, startsOn: "2026-10-27" },
      validWorkoutIds,
    ),
    false,
  );
  assert.equal(
    customProgramme.isCustomProgramme(
      { ...baseProgramme, weekCount: 17 },
      validWorkoutIds,
    ),
    false,
  );
  assert.equal(
    customProgramme.isCustomProgramme(
      {
        ...baseProgramme,
        assignments: [
          ...baseProgramme.assignments,
          { weekNumber: 1, dayIndex: 0, workoutId: "custom:lower" },
        ],
      },
      validWorkoutIds,
    ),
    false,
  );
  assert.equal(
    customProgramme.isCustomProgramme(
      {
        ...baseProgramme,
        assignments: [
          { weekNumber: 1, dayIndex: 0, workoutId: "custom:missing" },
        ],
      },
      validWorkoutIds,
    ),
    false,
  );
});

test("resolves scheduled, unplanned, before, after, and paused dates", () => {
  assert.deepEqual(
    customProgramme.resolveCustomProgrammeDay(
      baseProgramme,
      new Date(2026, 9, 26, 23, 30),
    ),
    {
      status: "scheduled",
      weekNumber: 1,
      dayIndex: 0,
      workoutId: "custom:upper",
    },
  );
  assert.deepEqual(
    customProgramme.resolveCustomProgrammeDay(
      baseProgramme,
      new Date(2026, 9, 27, 0, 30),
    ),
    { status: "unplanned", weekNumber: 1, dayIndex: 1 },
  );
  assert.deepEqual(
    customProgramme.resolveCustomProgrammeDay(
      baseProgramme,
      new Date(2026, 9, 25, 12),
    ),
    { status: "outside", reason: "before" },
  );
  assert.deepEqual(
    customProgramme.resolveCustomProgrammeDay(
      baseProgramme,
      new Date(2026, 10, 23, 12),
    ),
    { status: "outside", reason: "after" },
  );
  assert.deepEqual(
    customProgramme.resolveCustomProgrammeDay(
      { ...baseProgramme, enabled: false },
      new Date(2026, 9, 26, 12),
    ),
    { status: "outside", reason: "paused" },
  );
});

test("uses calendar days across a daylight-saving transition", () => {
  const programme = {
    ...baseProgramme,
    startsOn: "2026-10-26",
    weekCount: 2,
    assignments: [{ weekNumber: 2, dayIndex: 0, workoutId: "custom:upper" }],
  };
  assert.deepEqual(
    customProgramme.resolveCustomProgrammeDay(
      programme,
      new Date(2026, 10, 2, 0, 5),
    ),
    {
      status: "scheduled",
      weekNumber: 2,
      dayIndex: 0,
      workoutId: "custom:upper",
    },
  );
});

test("copies a week's exact slots into every later week", () => {
  assert.deepEqual(
    customProgramme.copyProgrammeWeekForward(
      [
        ...baseProgramme.assignments,
        { weekNumber: 2, dayIndex: 6, workoutId: "custom:lower" },
      ],
      1,
      3,
    ),
    [
      ...baseProgramme.assignments,
      { weekNumber: 2, dayIndex: 0, workoutId: "custom:upper" },
      { weekNumber: 2, dayIndex: 3, workoutId: "custom:lower" },
      { weekNumber: 3, dayIndex: 0, workoutId: "custom:upper" },
      { weekNumber: 3, dayIndex: 3, workoutId: "custom:lower" },
    ],
  );
});

test("removes every future assignment for a deleted template", () => {
  assert.deepEqual(
    customProgramme.removeProgrammeWorkoutAssignments(
      {
        ...baseProgramme,
        assignments: [
          ...baseProgramme.assignments,
          { weekNumber: 2, dayIndex: 0, workoutId: "custom:upper" },
        ],
      },
      "custom:upper",
      2_000,
    ),
    {
      ...baseProgramme,
      assignments: [{ weekNumber: 1, dayIndex: 3, workoutId: "custom:lower" }],
      updatedAt: 2_000,
    },
  );
});

test("returns the local week's Monday as an ISO date", () => {
  assert.equal(
    customProgramme.mondayIsoForLocalDate(new Date(2026, 6, 31, 18)),
    "2026-07-27",
  );
  assert.equal(customProgramme.isMondayIsoDate("2026-07-27"), true);
  assert.equal(customProgramme.isMondayIsoDate("2026-07-31"), false);
  assert.equal(customProgramme.mondayIsoForIsoDate("2026-07-31"), "2026-07-27");
});

test("migrates version 5 state and validates programme references in version 6", () => {
  const migrated = workoutState.parseStoredState({
    version: 5,
    updatedAt: 42,
    session: null,
    history: [],
    customWorkouts: [],
  });
  assert.deepEqual(migrated, {
    version: 6,
    updatedAt: 42,
    session: null,
    history: [],
    customWorkouts: [],
    customProgramme: null,
  });

  const custom = customWorkouts.duplicateWorkoutTemplate(
    {
      id: "upper",
      name: "Upper",
      scheduleName: "Upper",
      expectedMinutes: 10,
      notes: [],
      steps: [
        {
          id: "upper-step",
          exercise: "Press",
          setType: "Working",
          setLabel: "Set 1",
          tracking: "reps",
          targetWeight: null,
          targetReps: 8,
          targetRepsMax: null,
          targetDurationSeconds: null,
          restSeconds: 60,
          cue: "",
        },
      ],
    },
    "custom:upper",
    1_000,
  );
  const valid = {
    ...workoutState.emptyStoredState(),
    customWorkouts: [custom],
    customProgramme: {
      ...baseProgramme,
      assignments: [{ weekNumber: 1, dayIndex: 0, workoutId: "custom:upper" }],
    },
  };
  assert.deepEqual(workoutState.parseStoredState(valid), valid);
  assert.equal(
    workoutState.parseStoredState({
      ...valid,
      customWorkouts: [],
    }),
    null,
  );
});

test("round-trips a scheduled Week 16 custom session with its programme context", () => {
  const custom = customWorkouts.duplicateWorkoutTemplate(
    {
      id: "lower",
      name: "Lower",
      scheduleName: "Lower",
      expectedMinutes: 20,
      notes: [],
      steps: [
        {
          id: "lower-step",
          exercise: "Squat",
          setType: "Working",
          setLabel: "Set 1",
          tracking: "reps",
          targetWeight: null,
          targetReps: 6,
          targetRepsMax: null,
          targetDurationSeconds: null,
          restSeconds: 90,
          cue: "",
        },
      ],
    },
    "custom:lower",
    1_000,
  );
  const session = workoutState.makeWorkoutSession(custom, 16, 6, 2_000);
  const state = {
    ...workoutState.emptyStoredState(),
    session,
    customWorkouts: [custom],
    customProgramme: {
      ...baseProgramme,
      weekCount: 16,
      assignments: [{ weekNumber: 16, dayIndex: 6, workoutId: custom.id }],
    },
  };
  const parsed = workoutState.parseStoredState(state);
  assert.equal(parsed?.session?.weekNumber, 16);
  assert.equal(parsed?.session?.dayIndex, 6);
  assert.equal(parsed?.session?.workoutId, custom.id);
  assert.equal(parsed?.session?.records[0].step.exercise, "Squat");
});
