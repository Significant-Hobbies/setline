import type {
  CustomWorkoutId,
  PlannedStep,
  TrackingKind,
  WorkoutTemplate,
} from "./programme";

export type CustomWorkoutTemplate = WorkoutTemplate & {
  id: CustomWorkoutId;
  createdAt: number;
  updatedAt: number;
};

export const MAX_CUSTOM_WORKOUTS = 50;
export const MAX_CUSTOM_WORKOUT_STEPS = 100;
const MAX_CUSTOM_WORKOUT_NAME_LENGTH = 80;

const MAX_STEP_TEXT_LENGTH = 240;
const MAX_NOTE_LENGTH = 500;
const MAX_NOTES = 10;
const MAX_EXPECTED_MINUTES = 480;
const MAX_TARGET_VALUE = 10_000;
const MAX_REST_SECONDS = 3_600;
const TRACKING_KINDS = new Set<TrackingKind>([
  "weight-reps",
  "reps",
  "duration",
  "weight-duration",
  "completion",
]);
const STEP_TYPES = new Set([
  "Preparation",
  "Warm-up",
  "Working",
  "Cardio",
  "Mobility",
  "Cooldown",
  "Check",
]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function boundedText(
  value: unknown,
  maximum: number,
  allowEmpty = false,
): value is string {
  return (
    typeof value === "string" &&
    value.length <= maximum &&
    (allowEmpty || value.trim().length > 0)
  );
}

function nullableBoundedNumber(value: unknown): value is number | null {
  return (
    value === null ||
    (typeof value === "number" &&
      Number.isFinite(value) &&
      value >= 0 &&
      value <= MAX_TARGET_VALUE)
  );
}

function positiveInteger(
  value: unknown,
  maximum = MAX_TARGET_VALUE,
): value is number {
  return (
    Number.isInteger(value) && Number(value) > 0 && Number(value) <= maximum
  );
}

function targetShapeIsValid(
  step: Record<string, unknown>,
  tracking: TrackingKind,
) {
  const weight = step.targetWeight;
  const reps = step.targetReps;
  const repsMax = step.targetRepsMax;
  const duration = step.targetDurationSeconds;
  if (
    !nullableBoundedNumber(weight) ||
    !nullableBoundedNumber(reps) ||
    !nullableBoundedNumber(repsMax) ||
    !nullableBoundedNumber(duration)
  ) {
    return false;
  }
  if (repsMax !== null && (reps === null || repsMax < reps)) return false;
  if (tracking === "completion") {
    return (
      weight === null && reps === null && repsMax === null && duration === null
    );
  }
  if (tracking === "reps") {
    return (
      weight === null &&
      positiveInteger(reps) &&
      (repsMax === null || positiveInteger(repsMax)) &&
      duration === null
    );
  }
  if (tracking === "duration") {
    return (
      weight === null &&
      reps === null &&
      repsMax === null &&
      positiveInteger(duration)
    );
  }
  if (tracking === "weight-duration") {
    return reps === null && repsMax === null && positiveInteger(duration);
  }
  return (
    positiveInteger(reps) &&
    (repsMax === null || positiveInteger(repsMax)) &&
    duration === null
  );
}

function isCustomWorkoutStep(value: unknown): value is PlannedStep {
  if (!isRecord(value)) return false;
  const tracking = value.tracking;
  return (
    boundedText(value.id, MAX_STEP_TEXT_LENGTH) &&
    boundedText(value.exercise, MAX_STEP_TEXT_LENGTH) &&
    STEP_TYPES.has(String(value.setType)) &&
    boundedText(value.setLabel, MAX_STEP_TEXT_LENGTH) &&
    TRACKING_KINDS.has(tracking as TrackingKind) &&
    targetShapeIsValid(value, tracking as TrackingKind) &&
    Number.isInteger(value.restSeconds) &&
    Number(value.restSeconds) >= 0 &&
    Number(value.restSeconds) <= MAX_REST_SECONDS &&
    (value.targetRpe === undefined ||
      (typeof value.targetRpe === "number" &&
        Number.isFinite(value.targetRpe) &&
        value.targetRpe >= 0 &&
        value.targetRpe <= 10)) &&
    boundedText(value.cue, MAX_STEP_TEXT_LENGTH, true) &&
    (value.optional === undefined || typeof value.optional === "boolean")
  );
}

export function isCustomWorkoutTemplate(
  value: unknown,
): value is CustomWorkoutTemplate {
  if (!isRecord(value)) return false;
  if (
    typeof value.id !== "string" ||
    !value.id.startsWith("custom:") ||
    value.id.length > MAX_STEP_TEXT_LENGTH ||
    !boundedText(value.name, MAX_CUSTOM_WORKOUT_NAME_LENGTH) ||
    !boundedText(value.scheduleName, MAX_CUSTOM_WORKOUT_NAME_LENGTH) ||
    !positiveInteger(value.expectedMinutes, MAX_EXPECTED_MINUTES) ||
    !Array.isArray(value.steps) ||
    value.steps.length < 1 ||
    value.steps.length > MAX_CUSTOM_WORKOUT_STEPS ||
    !value.steps.every(isCustomWorkoutStep) ||
    new Set(value.steps.map((step) => step.id)).size !== value.steps.length ||
    !Array.isArray(value.notes) ||
    value.notes.length > MAX_NOTES ||
    !value.notes.every((note) => boundedText(note, MAX_NOTE_LENGTH, true)) ||
    typeof value.createdAt !== "number" ||
    !Number.isFinite(value.createdAt) ||
    value.createdAt < 0 ||
    typeof value.updatedAt !== "number" ||
    !Number.isFinite(value.updatedAt) ||
    value.updatedAt < value.createdAt
  ) {
    return false;
  }
  return true;
}

export function duplicateWorkoutTemplate(
  source: WorkoutTemplate,
  id: CustomWorkoutId,
  now = Date.now(),
): CustomWorkoutTemplate {
  const name = `${source.name} copy`.slice(0, MAX_CUSTOM_WORKOUT_NAME_LENGTH);
  return {
    id,
    name,
    scheduleName: name,
    expectedMinutes: source.expectedMinutes,
    steps: source.steps.map((step, index) => ({
      ...step,
      id: `${id}:step:${index + 1}`,
    })),
    notes: [...source.notes],
    createdAt: now,
    updatedAt: now,
  };
}

export function customWorkoutId(
  now = Date.now(),
  suffix = crypto.randomUUID(),
): CustomWorkoutId {
  return `custom:${now}:${suffix}`;
}

export function blankCustomWorkoutTemplate(
  id: CustomWorkoutId,
  now = Date.now(),
): CustomWorkoutTemplate {
  return {
    id,
    name: "",
    scheduleName: "",
    expectedMinutes: 45,
    steps: [
      {
        id: `${id}:step:1`,
        exercise: "",
        setType: "Working",
        setLabel: "Set 1",
        tracking: "weight-reps",
        targetWeight: null,
        targetReps: 8,
        targetRepsMax: null,
        targetDurationSeconds: null,
        restSeconds: 90,
        cue: "",
      },
    ],
    notes: [],
    createdAt: now,
    updatedAt: now,
  };
}
