export type SessionPhase = "active" | "rest" | "summary";
export type SetStatus = "pending" | "completed" | "skipped";

export type SetRecord = {
  setId: string;
  status: SetStatus;
  actualWeight: number;
  actualReps: number;
  actualRpe: number | null;
  completedAt: number | null;
};

export type WorkoutSession = {
  id: string;
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
  completedAt: number;
  durationSeconds: number;
  completedSets: number;
  skippedSets: number;
  workingVolume: number;
  warmupVolume: number;
  averageRpe: number | null;
  quality: number | null;
};

export type StoredState = {
  version: 2;
  updatedAt: number;
  session: WorkoutSession | null;
  history: HistoryEntry[];
};

export const STORAGE_KEY = "setline:v1";
export const PENDING_SYNC_KEY = "setline:sync-pending";

const WORKOUT_SET_IDS = [
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
];

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function isNullableNumber(value: unknown): value is number | null {
  return value === null || isFiniteNumber(value);
}

function isSetRecord(value: unknown, index: number): value is SetRecord {
  if (!value || typeof value !== "object") return false;
  const record = value as Partial<SetRecord>;
  return (
    record.setId === WORKOUT_SET_IDS[index] &&
    ["pending", "completed", "skipped"].includes(record.status ?? "") &&
    isFiniteNumber(record.actualWeight) &&
    record.actualWeight >= 0 &&
    isFiniteNumber(record.actualReps) &&
    record.actualReps >= 0 &&
    isNullableNumber(record.actualRpe) &&
    isNullableNumber(record.completedAt)
  );
}

function isWorkoutSession(value: unknown): value is WorkoutSession {
  if (!value || typeof value !== "object") return false;
  const session = value as Partial<WorkoutSession>;
  return (
    typeof session.id === "string" &&
    session.id.length > 0 &&
    isFiniteNumber(session.startedAt) &&
    isNullableNumber(session.completedAt) &&
    ["active", "rest", "summary"].includes(session.phase ?? "") &&
    Number.isInteger(session.activeIndex) &&
    (session.activeIndex ?? -1) >= 0 &&
    (session.activeIndex ?? WORKOUT_SET_IDS.length) < WORKOUT_SET_IDS.length &&
    isNullableNumber(session.restEndsAt) &&
    isNullableNumber(session.pausedRestSeconds) &&
    isFiniteNumber(session.plannedRestSeconds) &&
    Array.isArray(session.records) &&
    session.records.length === WORKOUT_SET_IDS.length &&
    session.records.every(isSetRecord) &&
    isNullableNumber(session.quality)
  );
}

function isHistoryEntry(value: unknown): value is HistoryEntry {
  if (!value || typeof value !== "object") return false;
  const entry = value as Partial<HistoryEntry>;
  return (
    typeof entry.id === "string" &&
    entry.id.length > 0 &&
    isFiniteNumber(entry.completedAt) &&
    isFiniteNumber(entry.durationSeconds) &&
    isFiniteNumber(entry.completedSets) &&
    isFiniteNumber(entry.skippedSets) &&
    isFiniteNumber(entry.workingVolume) &&
    isFiniteNumber(entry.warmupVolume) &&
    isNullableNumber(entry.averageRpe) &&
    isNullableNumber(entry.quality)
  );
}

export function emptyStoredState(): StoredState {
  return {
    version: 2,
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

  if (session === undefined || history === undefined) return null;
  if (
    candidate.version === 2 &&
    isFiniteNumber(candidate.updatedAt) &&
    candidate.updatedAt >= 0
  ) {
    return {
      version: 2,
      updatedAt: candidate.updatedAt,
      session,
      history,
    };
  }
  if (candidate.version === 1) {
    return {
      version: 2,
      updatedAt: migrationTime,
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
    version: 2,
    updatedAt: Math.max(Date.now(), current.updatedAt + 1),
  };
}
