import type { HistoryEntry } from "./workout-state";

export type ExerciseTrendMetric =
  | "weight"
  | "duration"
  | "repetitions"
  | "completions";

export type ExerciseTrendPoint = {
  historyId: string;
  workoutName: string;
  completedAt: number;
  completedExecutions: number;
  bestWeight: number | null;
  repetitionsAtBestWeight: number | null;
  bestRepetitions: number | null;
  longestDurationSeconds: number | null;
  workingVolume: number;
  averageRpe: number | null;
  rpeCount: number;
};

export type ExerciseAnalytics = {
  id: string;
  name: string;
  recordedSessions: number;
  completedExecutions: number;
  bestWeight: number | null;
  repetitionsAtBestWeight: number | null;
  bestRepetitions: number | null;
  longestDurationSeconds: number | null;
  totalWorkingVolume: number;
  averageRpe: number | null;
  rpeCount: number;
  trendMetric: ExerciseTrendMetric;
  latest: ExerciseTrendPoint;
  trend: ExerciseTrendPoint[];
};

export type WorkoutAnalytics = {
  workoutId: HistoryEntry["workoutId"];
  workoutName: string;
  recordedSessions: number;
  detailedSessions: number;
  latestCompletedAt: number;
  totalDurationSeconds: number;
  averageDurationSeconds: number;
  totalWorkingVolume: number;
  completedSets: number;
  modifiedSets: number;
  skippedSets: number;
};

export type ProgrammeWeekAnalytics = {
  weekNumber: number;
  recordedSessions: number;
  latestCompletedAt: number;
  totalWorkingVolume: number;
  completedSets: number;
  modifiedSets: number;
  skippedSets: number;
};

export type HistoryAnalytics = {
  overview: {
    recordedSessions: number;
    detailedSessions: number;
    customSessions: number;
    totalDurationSeconds: number;
    totalWorkingVolume: number;
    latestCompletedAt: number | null;
  };
  exercises: ExerciseAnalytics[];
  workouts: WorkoutAnalytics[];
  programmeWeeks: ProgrammeWeekAnalytics[];
};

type MutableExercisePoint = ExerciseTrendPoint & {
  name: string;
  rpeTotal: number;
};

type MutableExercise = {
  id: string;
  name: string;
  points: ExerciseTrendPoint[];
};

type MutableWorkout = Omit<WorkoutAnalytics, "averageDurationSeconds">;

export function normalizeExerciseName(name: string) {
  return name.trim().replace(/\s+/g, " ").toLocaleLowerCase();
}

function positive(value: number | null | undefined): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function nonNegative(value: number) {
  return Number.isFinite(value) && value >= 0 ? value : 0;
}

function trendValue(point: ExerciseTrendPoint, metric: ExerciseTrendMetric) {
  if (metric === "weight") return point.bestWeight;
  if (metric === "duration") return point.longestDurationSeconds;
  if (metric === "repetitions") return point.bestRepetitions;
  return point.completedExecutions;
}

function summarizeExercisePoints(points: ExerciseTrendPoint[]) {
  let bestWeight: number | null = null;
  let repetitionsAtBestWeight: number | null = null;
  let bestRepetitions: number | null = null;
  let longestDurationSeconds: number | null = null;
  let completedExecutions = 0;
  let totalWorkingVolume = 0;
  let rpeCount = 0;
  let rpeTotal = 0;

  for (const point of points) {
    completedExecutions += point.completedExecutions;
    totalWorkingVolume += point.workingVolume;
    rpeCount += point.rpeCount;
    rpeTotal += (point.averageRpe ?? 0) * point.rpeCount;

    if (point.bestWeight !== null) {
      if (bestWeight === null || point.bestWeight > bestWeight) {
        bestWeight = point.bestWeight;
        repetitionsAtBestWeight = point.repetitionsAtBestWeight;
      } else if (
        point.bestWeight === bestWeight &&
        point.repetitionsAtBestWeight !== null
      ) {
        repetitionsAtBestWeight = Math.max(
          repetitionsAtBestWeight ?? 0,
          point.repetitionsAtBestWeight,
        );
      }
    }
    if (
      point.bestRepetitions !== null &&
      (bestRepetitions === null || point.bestRepetitions > bestRepetitions)
    ) {
      bestRepetitions = point.bestRepetitions;
    }
    if (
      point.longestDurationSeconds !== null &&
      (longestDurationSeconds === null ||
        point.longestDurationSeconds > longestDurationSeconds)
    ) {
      longestDurationSeconds = point.longestDurationSeconds;
    }
  }

  const trendMetric: ExerciseTrendMetric =
    bestWeight !== null
      ? "weight"
      : longestDurationSeconds !== null
        ? "duration"
        : bestRepetitions !== null
          ? "repetitions"
          : "completions";
  return {
    bestWeight,
    repetitionsAtBestWeight,
    bestRepetitions,
    longestDurationSeconds,
    completedExecutions,
    totalWorkingVolume,
    averageRpe: rpeCount ? rpeTotal / rpeCount : null,
    rpeCount,
    trendMetric,
    metricPoints: points.filter(
      (point) => trendValue(point, trendMetric) !== null,
    ),
  };
}

function makeExercisePoint(
  historyId: string,
  workoutName: string,
  completedAt: number,
  name: string,
): MutableExercisePoint {
  return {
    historyId,
    workoutName,
    completedAt,
    name,
    completedExecutions: 0,
    bestWeight: null,
    repetitionsAtBestWeight: null,
    bestRepetitions: null,
    longestDurationSeconds: null,
    workingVolume: 0,
    averageRpe: null,
    rpeCount: 0,
    rpeTotal: 0,
  };
}

export function deriveHistoryAnalytics(
  history: HistoryEntry[],
): HistoryAnalytics {
  const ordered = [...history].sort(
    (left, right) => right.completedAt - left.completedAt,
  );
  const exerciseGroups = new Map<string, MutableExercise>();
  const workoutGroups = new Map<HistoryEntry["workoutId"], MutableWorkout>();
  const programmeWeeks = new Map<number, ProgrammeWeekAnalytics>();

  for (const entry of ordered) {
    const existingWorkout = workoutGroups.get(entry.workoutId);
    const workout =
      existingWorkout ??
      ({
        workoutId: entry.workoutId,
        workoutName: entry.workoutName,
        recordedSessions: 0,
        detailedSessions: 0,
        latestCompletedAt: entry.completedAt,
        totalDurationSeconds: 0,
        totalWorkingVolume: 0,
        completedSets: 0,
        modifiedSets: 0,
        skippedSets: 0,
      } satisfies MutableWorkout);
    workout.recordedSessions += 1;
    workout.detailedSessions += entry.detailsAvailable ? 1 : 0;
    workout.totalDurationSeconds += nonNegative(entry.durationSeconds);
    workout.totalWorkingVolume += nonNegative(entry.workingVolume);
    workout.completedSets += nonNegative(entry.completedSets);
    workout.modifiedSets += nonNegative(entry.modifiedSets);
    workout.skippedSets += nonNegative(entry.skippedSets);
    workoutGroups.set(entry.workoutId, workout);

    if (
      !entry.workoutId.startsWith("custom:") &&
      Number.isInteger(entry.weekNumber) &&
      entry.weekNumber > 0
    ) {
      const existingWeek = programmeWeeks.get(entry.weekNumber);
      const week =
        existingWeek ??
        ({
          weekNumber: entry.weekNumber,
          recordedSessions: 0,
          latestCompletedAt: entry.completedAt,
          totalWorkingVolume: 0,
          completedSets: 0,
          modifiedSets: 0,
          skippedSets: 0,
        } satisfies ProgrammeWeekAnalytics);
      week.recordedSessions += 1;
      week.totalWorkingVolume += nonNegative(entry.workingVolume);
      week.completedSets += nonNegative(entry.completedSets);
      week.modifiedSets += nonNegative(entry.modifiedSets);
      week.skippedSets += nonNegative(entry.skippedSets);
      programmeWeeks.set(entry.weekNumber, week);
    }

    if (!entry.detailsAvailable) continue;
    const exercisePoints = new Map<string, MutableExercisePoint>();

    for (const execution of entry.executions) {
      if (execution.status !== "completed") continue;
      const exerciseId = normalizeExerciseName(execution.step.exercise);
      if (!exerciseId) continue;
      const point =
        exercisePoints.get(exerciseId) ??
        makeExercisePoint(
          entry.id,
          entry.workoutName,
          entry.completedAt,
          execution.step.exercise.trim().replace(/\s+/g, " "),
        );
      point.completedExecutions += 1;

      for (const segment of execution.segments) {
        if (positive(segment.reps)) {
          point.bestRepetitions = Math.max(
            point.bestRepetitions ?? 0,
            segment.reps,
          );
        }
        if (positive(segment.durationSeconds)) {
          point.longestDurationSeconds = Math.max(
            point.longestDurationSeconds ?? 0,
            segment.durationSeconds,
          );
        }
        if (positive(segment.weight)) {
          if (
            point.bestWeight === null ||
            segment.weight > point.bestWeight
          ) {
            point.bestWeight = segment.weight;
            point.repetitionsAtBestWeight = positive(segment.reps)
              ? segment.reps
              : null;
          } else if (
            segment.weight === point.bestWeight &&
            positive(segment.reps)
          ) {
            point.repetitionsAtBestWeight = Math.max(
              point.repetitionsAtBestWeight ?? 0,
              segment.reps,
            );
          }
        }
        if (
          execution.step.setType === "Working" &&
          positive(segment.weight) &&
          positive(segment.reps)
        ) {
          point.workingVolume += segment.weight * segment.reps;
        }
      }

      if (
        typeof execution.actualRpe === "number" &&
        Number.isFinite(execution.actualRpe)
      ) {
        point.rpeTotal += execution.actualRpe;
        point.rpeCount += 1;
        point.averageRpe = point.rpeTotal / point.rpeCount;
      }
      exercisePoints.set(exerciseId, point);
    }

    for (const [exerciseId, mutablePoint] of exercisePoints) {
      const point: ExerciseTrendPoint = {
        historyId: mutablePoint.historyId,
        workoutName: mutablePoint.workoutName,
        completedAt: mutablePoint.completedAt,
        completedExecutions: mutablePoint.completedExecutions,
        bestWeight: mutablePoint.bestWeight,
        repetitionsAtBestWeight: mutablePoint.repetitionsAtBestWeight,
        bestRepetitions: mutablePoint.bestRepetitions,
        longestDurationSeconds: mutablePoint.longestDurationSeconds,
        workingVolume: mutablePoint.workingVolume,
        averageRpe: mutablePoint.averageRpe,
        rpeCount: mutablePoint.rpeCount,
      };
      const group =
        exerciseGroups.get(exerciseId) ??
        ({
          id: exerciseId,
          name: mutablePoint.name,
          points: [],
        } satisfies MutableExercise);
      group.points.push(point);
      exerciseGroups.set(exerciseId, group);
    }
  }

  const exercises = Array.from(exerciseGroups.values())
    .map((group): ExerciseAnalytics => {
      const summary = summarizeExercisePoints(group.points);
      return {
        id: group.id,
        name: group.name,
        recordedSessions: group.points.length,
        completedExecutions: summary.completedExecutions,
        bestWeight: summary.bestWeight,
        repetitionsAtBestWeight: summary.repetitionsAtBestWeight,
        bestRepetitions: summary.bestRepetitions,
        longestDurationSeconds: summary.longestDurationSeconds,
        totalWorkingVolume: summary.totalWorkingVolume,
        averageRpe: summary.averageRpe,
        rpeCount: summary.rpeCount,
        trendMetric: summary.trendMetric,
        latest: summary.metricPoints[0] ?? group.points[0],
        trend: summary.metricPoints.slice(0, 8).reverse(),
      };
    })
    .sort((left, right) => {
      const recent = right.latest.completedAt - left.latest.completedAt;
      return recent || left.name.localeCompare(right.name);
    });

  return {
    overview: {
      recordedSessions: ordered.length,
      detailedSessions: ordered.filter((entry) => entry.detailsAvailable).length,
      customSessions: ordered.filter((entry) =>
        entry.workoutId.startsWith("custom:"),
      ).length,
      totalDurationSeconds: ordered.reduce(
        (total, entry) => total + nonNegative(entry.durationSeconds),
        0,
      ),
      totalWorkingVolume: ordered.reduce(
        (total, entry) => total + nonNegative(entry.workingVolume),
        0,
      ),
      latestCompletedAt: ordered[0]?.completedAt ?? null,
    },
    exercises,
    workouts: Array.from(workoutGroups.values())
      .map((workout): WorkoutAnalytics => ({
        ...workout,
        averageDurationSeconds:
          workout.recordedSessions > 0
            ? workout.totalDurationSeconds / workout.recordedSessions
            : 0,
      }))
      .sort((left, right) => {
        const recent = right.latestCompletedAt - left.latestCompletedAt;
        return recent || left.workoutName.localeCompare(right.workoutName);
      }),
    programmeWeeks: Array.from(programmeWeeks.values()).sort(
      (left, right) => left.weekNumber - right.weekNumber,
    ),
  };
}
