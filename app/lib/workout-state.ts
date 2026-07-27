import {
  LEGACY_UPPER_STEPS,
  resolveWorkout,
  type WorkoutId,
} from "./programme";

export type SessionPhase = "active" | "rest" | "summary";
export type SetStatus = "pending" | "completed" | "skipped";

export type SetRecord = {
  setId: string;
  status: SetStatus;
  actualWeight: number | null;
  actualReps: number | null;
  actualDurationSeconds: number | null;
  actualRpe: number | null;
  completedAt: number | null;
};

export type WorkoutSession = {
  id: string;
  workoutId: WorkoutId;
  workoutName: string;
  weekNumber: number;
  dayIndex: number;
  startedAt: number;
  completedAt: number | null;
  phase: SessionPhase;
  activeIndex: number;
  restEndsAt: number | null;
  pausedRestSeconds: number | null;
  plannedRestSeconds: number;
  records: SetRecord[];
  quality: number | null;
};

export type HistoryEntry = {
  id: string;
  workoutId: WorkoutId;
  workoutName: string;
  weekNumber: number;
  completedAt: number;
  durationSeconds: number;
  completedSets: number;
  skippedSets: number;
  workingVolume: number;
  warmupVolume: number;
  completedDurationSeconds: number;
  averageRpe: number | null;
  quality: number | null;
};

export type StoredState = {
  version: 3;
  updatedAt: number;
  session: WorkoutSession | null;
  history: HistoryEntry[];
};

export const STORAGE_KEY = "setline:v1";
export const PENDING_SYNC_KEY = "setline:sync-pending";

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function isNullableNumber(value: unknown): value is number | null {
  return value === null || isFiniteNumber(value);
}

function isWorkoutId(value: unknown): value is WorkoutId {
  return [
    "upper",
    "lower",
    "easy-mobility",
    "upper-hard",
    "mobility",
    "legacy-upper-a",
  ].includes(String(value));
}

function isSetRecord(value: unknown, expectedId: string): value is SetRecord {
  if (!value || typeof value !== "object") return false;
  const record = value as Partial<SetRecord>;
  return (
    record.setId === expectedId &&
    ["pending", "completed", "skipped"].includes(record.status ?? "") &&
    isNullableNumber(record.actualWeight) &&
    (record.actualWeight === null || record.actualWeight >= 0) &&
    isNullableNumber(record.actualReps) &&
    (record.actualReps === null || record.actualReps >= 0) &&
    isNullableNumber(record.actualDurationSeconds) &&
    (record.actualDurationSeconds === null || record.actualDurationSeconds >= 0) &&
    isNullableNumber(record.actualRpe) &&
    (record.actualRpe === null || (record.actualRpe >= 0 && record.actualRpe <= 10)) &&
    isNullableNumber(record.completedAt)
  );
}

function isWorkoutSession(value: unknown): value is WorkoutSession {
  if (!value || typeof value !== "object") return false;
  const session = value as Partial<WorkoutSession>;
  if (
    typeof session.id !== "string" ||
    !session.id ||
    !isWorkoutId(session.workoutId) ||
    typeof session.workoutName !== "string" ||
    !session.workoutName ||
    !Number.isInteger(session.weekNumber) ||
    (session.weekNumber ?? 0) < 1 ||
    (session.weekNumber ?? 13) > 12 ||
    !Number.isInteger(session.dayIndex) ||
    (session.dayIndex ?? -1) < 0 ||
    (session.dayIndex ?? 7) > 6 ||
    !isFiniteNumber(session.startedAt) ||
    !isNullableNumber(session.completedAt) ||
    !["active", "rest", "summary"].includes(session.phase ?? "") ||
    !Number.isInteger(session.activeIndex) ||
    !isNullableNumber(session.restEndsAt) ||
    !isNullableNumber(session.pausedRestSeconds) ||
    !isFiniteNumber(session.plannedRestSeconds) ||
    !Array.isArray(session.records) ||
    !isNullableNumber(session.quality)
  ) {
    return false;
  }
  const template = resolveWorkout(
    session.workoutId,
    session.weekNumber as number,
    session.dayIndex as number,
  );
  return (
    session.records.length === template.steps.length &&
    (session.activeIndex ?? -1) >= 0 &&
    (session.activeIndex ?? template.steps.length) < template.steps.length &&
    session.records.every((record, index) =>
      isSetRecord(record, template.steps[index].id),
    )
  );
}

function isHistoryEntry(value: unknown): value is HistoryEntry {
  if (!value || typeof value !== "object") return false;
  const entry = value as Partial<HistoryEntry>;
  return (
    typeof entry.id === "string" &&
    entry.id.length > 0 &&
    isWorkoutId(entry.workoutId) &&
    typeof entry.workoutName === "string" &&
    entry.workoutName.length > 0 &&
    Number.isInteger(entry.weekNumber) &&
    (entry.weekNumber ?? 0) >= 1 &&
    (entry.weekNumber ?? 13) <= 12 &&
    isFiniteNumber(entry.completedAt) &&
    isFiniteNumber(entry.durationSeconds) &&
    isFiniteNumber(entry.completedSets) &&
    isFiniteNumber(entry.skippedSets) &&
    isFiniteNumber(entry.workingVolume) &&
    isFiniteNumber(entry.warmupVolume) &&
    isFiniteNumber(entry.completedDurationSeconds) &&
    isNullableNumber(entry.averageRpe) &&
    isNullableNumber(entry.quality)
  );
}

type LegacyRecord = {
  setId?: unknown;
  status?: unknown;
  actualWeight?: unknown;
  actualReps?: unknown;
  actualRpe?: unknown;
  completedAt?: unknown;
};

type LegacySession = {
  id?: unknown;
  startedAt?: unknown;
  completedAt?: unknown;
  phase?: unknown;
  activeIndex?: unknown;
  restEndsAt?: unknown;
  pausedRestSeconds?: unknown;
  plannedRestSeconds?: unknown;
  records?: unknown;
  quality?: unknown;
};

type LegacyHistory = {
  id?: unknown;
  completedAt?: unknown;
  durationSeconds?: unknown;
  completedSets?: unknown;
  skippedSets?: unknown;
  workingVolume?: unknown;
  warmupVolume?: unknown;
  averageRpe?: unknown;
  quality?: unknown;
};

function migrateLegacySession(value: unknown): WorkoutSession | null | undefined {
  if (value === null) return null;
  if (!value || typeof value !== "object") return undefined;
  const session = value as LegacySession;
  if (
    typeof session.id !== "string" ||
    !isFiniteNumber(session.startedAt) ||
    !isNullableNumber(session.completedAt) ||
    !["active", "rest", "summary"].includes(String(session.phase)) ||
    !Number.isInteger(session.activeIndex) ||
    !isNullableNumber(session.restEndsAt) ||
    !isNullableNumber(session.pausedRestSeconds) ||
    !isFiniteNumber(session.plannedRestSeconds) ||
    !Array.isArray(session.records) ||
    session.records.length !== LEGACY_UPPER_STEPS.length ||
    !isNullableNumber(session.quality)
  ) {
    return undefined;
  }
  const records = session.records.map((value, index) => {
    if (!value || typeof value !== "object") return null;
    const record = value as LegacyRecord;
    if (
      record.setId !== LEGACY_UPPER_STEPS[index].id ||
      !["pending", "completed", "skipped"].includes(String(record.status)) ||
      !isFiniteNumber(record.actualWeight) ||
      !isFiniteNumber(record.actualReps) ||
      !isNullableNumber(record.actualRpe) ||
      !isNullableNumber(record.completedAt)
    ) {
      return null;
    }
    return {
      setId: record.setId,
      status: record.status as SetStatus,
      actualWeight: record.actualWeight,
      actualReps: record.actualReps,
      actualDurationSeconds: null,
      actualRpe: record.actualRpe,
      completedAt: record.completedAt,
    } satisfies SetRecord;
  });
  if (records.some((record) => record === null)) return undefined;
  return {
    id: session.id,
    workoutId: "legacy-upper-a",
    workoutName: "Upper A · legacy sample",
    weekNumber: 1,
    dayIndex: 0,
    startedAt: session.startedAt,
    completedAt: session.completedAt,
    phase: session.phase as SessionPhase,
    activeIndex: session.activeIndex as number,
    restEndsAt: session.restEndsAt,
    pausedRestSeconds: session.pausedRestSeconds,
    plannedRestSeconds: session.plannedRestSeconds,
    records: records as SetRecord[],
    quality: session.quality,
  };
}

function migrateLegacyHistory(value: unknown): HistoryEntry[] | undefined {
  if (!Array.isArray(value) || value.length > 500) return undefined;
  const entries = value.map((item) => {
    if (!item || typeof item !== "object") return null;
    const entry = item as LegacyHistory;
    if (
      typeof entry.id !== "string" ||
      !isFiniteNumber(entry.completedAt) ||
      !isFiniteNumber(entry.durationSeconds) ||
      !isFiniteNumber(entry.completedSets) ||
      !isFiniteNumber(entry.skippedSets) ||
      !isFiniteNumber(entry.workingVolume) ||
      !isFiniteNumber(entry.warmupVolume) ||
      !isNullableNumber(entry.averageRpe) ||
      !isNullableNumber(entry.quality)
    ) {
      return null;
    }
    return {
      id: entry.id,
      workoutId: "legacy-upper-a",
      workoutName: "Upper A · legacy sample",
      weekNumber: 1,
      completedAt: entry.completedAt,
      durationSeconds: entry.durationSeconds,
      completedSets: entry.completedSets,
      skippedSets: entry.skippedSets,
      workingVolume: entry.workingVolume,
      warmupVolume: entry.warmupVolume,
      completedDurationSeconds: 0,
      averageRpe: entry.averageRpe,
      quality: entry.quality,
    } satisfies HistoryEntry;
  });
  return entries.some((entry) => entry === null)
    ? undefined
    : (entries as HistoryEntry[]);
}

export function emptyStoredState(): StoredState {
  return {
    version: 3,
    updatedAt: 0,
    session: null,
    history: [],
  };
}

export function parseStoredState(value: unknown, migrationTime = Date.now()): StoredState | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as {
    version?: unknown;
    updatedAt?: unknown;
    session?: unknown;
    history?: unknown;
  };

  if (candidate.version === 3) {
    const session =
      candidate.session === null || isWorkoutSession(candidate.session)
        ? candidate.session
        : undefined;
    const history =
      Array.isArray(candidate.history) &&
      candidate.history.length <= 500 &&
      candidate.history.every(isHistoryEntry)
        ? candidate.history
        : undefined;
    if (
      session === undefined ||
      history === undefined ||
      !isFiniteNumber(candidate.updatedAt) ||
      candidate.updatedAt < 0
    ) {
      return null;
    }
    return {
      version: 3,
      updatedAt: candidate.updatedAt,
      session,
      history,
    };
  }

  if (candidate.version === 1 || candidate.version === 2) {
    const session = migrateLegacySession(candidate.session);
    const history = migrateLegacyHistory(candidate.history);
    if (session === undefined || history === undefined) return null;
    return {
      version: 3,
      updatedAt:
        candidate.version === 2 &&
        isFiniteNumber(candidate.updatedAt) &&
        candidate.updatedAt >= 0
          ? candidate.updatedAt
          : migrationTime,
      session,
      history,
    };
  }
  return null;
}

export function parseStoredStateJson(raw: string | null) {
  if (!raw) return null;
  try {
    return parseStoredState(JSON.parse(raw) as unknown);
  } catch {
    return null;
  }
}

export function updateStoredState(
  current: StoredState,
  patch: Partial<Pick<StoredState, "session" | "history">>,
): StoredState {
  return {
    ...current,
    ...patch,
    version: 3,
    updatedAt: Math.max(Date.now(), current.updatedAt + 1),
  };
}
