import type {
  ExecutionRecord,
  HistoryEntry,
  StepSnapshot,
} from "./workout-state";

export type ProgressionRecommendation = {
  sourceHistoryId: string;
  sourceWorkoutName: string;
  sourceCompletedAt: number;
  evidenceSetCount: number;
  previousWeight: number;
  repetitionThreshold: number;
  rpeCeiling: number;
  suggestedWeight: number;
  suggestedReps: number;
};

export function applyProgressionValues(
  record: ExecutionRecord,
  weight: number,
  reps: number,
): ExecutionRecord {
  if (
    record.step.tracking !== "weight-reps" ||
    record.segments.length !== 1 ||
    !Number.isFinite(weight) ||
    weight < 0 ||
    !Number.isInteger(reps) ||
    reps <= 0
  ) {
    return record;
  }

  return {
    ...record,
    segments: [
      {
        ...record.segments[0],
        weight,
        reps,
      },
    ],
  };
}

function normalizedExerciseName(name: string) {
  return name.trim().toLocaleLowerCase("en-US").replace(/\s+/g, " ");
}

function comparableExecutions(
  history: HistoryEntry,
  exerciseName: string,
): ExecutionRecord[] {
  const normalizedName = normalizedExerciseName(exerciseName);
  return history.executions.filter(
    (record) =>
      record.source === "planned" &&
      record.status === "completed" &&
      record.step.setType === "Working" &&
      record.step.tracking === "weight-reps" &&
      record.segments.length === 1 &&
      normalizedExerciseName(record.step.exercise) === normalizedName,
  );
}

export function getProgressionRecommendation(
  step: StepSnapshot,
  history: HistoryEntry[],
): ProgressionRecommendation | null {
  if (
    step.setType !== "Working" ||
    step.tracking !== "weight-reps" ||
    step.targetWeight === null ||
    step.targetWeight <= 0 ||
    step.targetReps === null ||
    step.targetReps <= 0 ||
    step.targetRepsMax === null ||
    step.targetRepsMax <= step.targetReps ||
    step.targetRpe === undefined ||
    step.targetRpe < 0 ||
    step.targetRpe > 10
  ) {
    return null;
  }

  const latestComparable = [...history]
    .sort((left, right) => right.completedAt - left.completedAt)
    .map((entry) => ({
      entry,
      executions: comparableExecutions(entry, step.exercise),
    }))
    .find(({ executions }) => executions.length > 0);

  if (!latestComparable || latestComparable.executions.length < 2) {
    return null;
  }

  const clearsThreshold = latestComparable.executions.every((record) => {
    const segment = record.segments[0];
    return (
      segment.weight === step.targetWeight &&
      segment.reps !== null &&
      segment.reps >= step.targetRepsMax! &&
      record.actualRpe !== null &&
      record.actualRpe <= step.targetRpe!
    );
  });

  if (!clearsThreshold) return null;

  return {
    sourceHistoryId: latestComparable.entry.id,
    sourceWorkoutName: latestComparable.entry.workoutName,
    sourceCompletedAt: latestComparable.entry.completedAt,
    evidenceSetCount: latestComparable.executions.length,
    previousWeight: step.targetWeight,
    repetitionThreshold: step.targetRepsMax,
    rpeCeiling: step.targetRpe,
    suggestedWeight: step.targetWeight + 2.5,
    suggestedReps: step.targetReps,
  };
}
