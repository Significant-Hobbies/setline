import type { CustomWorkoutId } from "./programme";

export type CustomProgrammeAssignment = {
  weekNumber: number;
  dayIndex: number;
  workoutId: CustomWorkoutId;
};

export type CustomProgramme = {
  name: string;
  startsOn: string;
  weekCount: number;
  enabled: boolean;
  assignments: CustomProgrammeAssignment[];
  createdAt: number;
  updatedAt: number;
};

export type CustomProgrammeDayResolution =
  | {
      status: "outside";
      reason: "paused" | "before" | "after";
    }
  | {
      status: "unplanned";
      weekNumber: number;
      dayIndex: number;
    }
  | {
      status: "scheduled";
      weekNumber: number;
      dayIndex: number;
      workoutId: CustomWorkoutId;
    };

export const MAX_CUSTOM_PROGRAMME_WEEKS = 16;
export const MAX_CUSTOM_PROGRAMME_NAME_LENGTH = 80;

const DAYS_PER_WEEK = 7;
const MILLISECONDS_PER_DAY = 86_400_000;
const ISO_DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseIsoCalendarDay(value: unknown): number | null {
  if (typeof value !== "string") return null;
  const match = ISO_DATE_PATTERN.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const ordinal = Date.UTC(year, month - 1, day);
  const parsed = new Date(ordinal);
  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return null;
  }
  return ordinal;
}

function localCalendarDay(date: Date): number | null {
  if (!Number.isFinite(date.getTime())) return null;
  return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
}

function isMonday(ordinal: number) {
  return new Date(ordinal).getUTCDay() === 1;
}

export function isMondayIsoDate(value: string) {
  const ordinal = parseIsoCalendarDay(value);
  return ordinal !== null && isMonday(ordinal);
}

export function mondayIsoForIsoDate(value: string) {
  const ordinal = parseIsoCalendarDay(value);
  if (ordinal === null) return "";
  const dayIndex = (new Date(ordinal).getUTCDay() + 6) % DAYS_PER_WEEK;
  return new Date(ordinal - dayIndex * MILLISECONDS_PER_DAY)
    .toISOString()
    .slice(0, 10);
}

export function isCustomProgramme(
  value: unknown,
  validWorkoutIds: ReadonlySet<string>,
): value is CustomProgramme {
  if (!isRecord(value)) return false;
  const startsOn = parseIsoCalendarDay(value.startsOn);
  if (
    typeof value.name !== "string" ||
    value.name.trim().length === 0 ||
    value.name.length > MAX_CUSTOM_PROGRAMME_NAME_LENGTH ||
    startsOn === null ||
    !isMonday(startsOn) ||
    !Number.isInteger(value.weekCount) ||
    Number(value.weekCount) < 1 ||
    Number(value.weekCount) > MAX_CUSTOM_PROGRAMME_WEEKS ||
    typeof value.enabled !== "boolean" ||
    !Array.isArray(value.assignments) ||
    value.assignments.length > Number(value.weekCount) * DAYS_PER_WEEK ||
    typeof value.createdAt !== "number" ||
    !Number.isFinite(value.createdAt) ||
    value.createdAt < 0 ||
    typeof value.updatedAt !== "number" ||
    !Number.isFinite(value.updatedAt) ||
    value.updatedAt < value.createdAt
  ) {
    return false;
  }

  const slots = new Set<string>();
  for (const assignment of value.assignments) {
    if (!isRecord(assignment)) return false;
    if (
      !Number.isInteger(assignment.weekNumber) ||
      Number(assignment.weekNumber) < 1 ||
      Number(assignment.weekNumber) > Number(value.weekCount) ||
      !Number.isInteger(assignment.dayIndex) ||
      Number(assignment.dayIndex) < 0 ||
      Number(assignment.dayIndex) >= DAYS_PER_WEEK ||
      typeof assignment.workoutId !== "string" ||
      !assignment.workoutId.startsWith("custom:") ||
      !validWorkoutIds.has(assignment.workoutId)
    ) {
      return false;
    }
    const slot = `${assignment.weekNumber}:${assignment.dayIndex}`;
    if (slots.has(slot)) return false;
    slots.add(slot);
  }
  return true;
}

export function resolveCustomProgrammeDay(
  programme: CustomProgramme,
  date: Date,
): CustomProgrammeDayResolution {
  if (!programme.enabled) return { status: "outside", reason: "paused" };
  const start = parseIsoCalendarDay(programme.startsOn);
  const current = localCalendarDay(date);
  if (start === null || current === null || current < start) {
    return { status: "outside", reason: "before" };
  }
  const offset = Math.round((current - start) / MILLISECONDS_PER_DAY);
  if (offset >= programme.weekCount * DAYS_PER_WEEK) {
    return { status: "outside", reason: "after" };
  }
  const weekNumber = Math.floor(offset / DAYS_PER_WEEK) + 1;
  const dayIndex = offset % DAYS_PER_WEEK;
  const assignment = programme.assignments.find(
    (candidate) =>
      candidate.weekNumber === weekNumber && candidate.dayIndex === dayIndex,
  );
  return assignment
    ? {
        status: "scheduled",
        weekNumber,
        dayIndex,
        workoutId: assignment.workoutId,
      }
    : { status: "unplanned", weekNumber, dayIndex };
}

export function copyProgrammeWeekForward(
  assignments: CustomProgrammeAssignment[],
  sourceWeek: number,
  weekCount: number,
): CustomProgrammeAssignment[] {
  if (
    !Number.isInteger(sourceWeek) ||
    !Number.isInteger(weekCount) ||
    sourceWeek < 1 ||
    weekCount < 1 ||
    sourceWeek > weekCount ||
    weekCount > MAX_CUSTOM_PROGRAMME_WEEKS
  ) {
    return assignments;
  }
  const source = assignments.filter(
    (assignment) => assignment.weekNumber === sourceWeek,
  );
  return [
    ...assignments.filter((assignment) => assignment.weekNumber <= sourceWeek),
    ...Array.from(
      { length: weekCount - sourceWeek },
      (_, index) => sourceWeek + index + 1,
    ).flatMap((weekNumber) =>
      source.map((assignment) => ({ ...assignment, weekNumber })),
    ),
  ];
}

export function removeProgrammeWorkoutAssignments(
  programme: CustomProgramme | null,
  workoutId: CustomWorkoutId,
  updatedAt = Date.now(),
): CustomProgramme | null {
  if (!programme) return null;
  const assignments = programme.assignments.filter(
    (assignment) => assignment.workoutId !== workoutId,
  );
  return assignments.length === programme.assignments.length
    ? programme
    : { ...programme, assignments, updatedAt };
}

export function mondayIsoForLocalDate(date: Date) {
  if (!Number.isFinite(date.getTime())) return "";
  const dayIndex = (date.getDay() + 6) % DAYS_PER_WEEK;
  const monday = new Date(date.getFullYear(), date.getMonth(), date.getDate() - dayIndex);
  const year = monday.getFullYear();
  const month = String(monday.getMonth() + 1).padStart(2, "0");
  const day = String(monday.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}
