import {
  LEGACY_UPPER_STEPS,
  resolveWorkout,
  type PlannedStep,
  type StepType,
  type TrackingKind,
  type WorkoutId,
  type WorkoutTemplate,
} from "./programme";

export type SessionPhase = "active" | "rest" | "summary";
export type ExecutionStatus = "pending" | "completed" | "skipped";
export type ExecutionSource = "planned" | "extra";

export type SetSegment = {
  id: string;
  weight: number | null;
  reps: number | null;
  durationSeconds: number | null;
};

export type StepSnapshot = {
  id: string;
  plannedStepId: string | null;
  exercise: string;
  setType: StepType;
  setLabel: string;
  tracking: TrackingKind;
  targetWeight: number | null;
  targetReps: number | null;
  targetRepsMax: number | null;
  targetDurationSeconds: number | null;
  restSeconds: number;
  targetRpe?: number;
  cue: string;
  optional: boolean;
};

export type ExecutionRecord = {
  id: string;
  source: ExecutionSource;
  clonedFromId: string | null;
  plannedPosition: number | null;
  performedPosition: number | null;
  deferred: boolean;
  status: ExecutionStatus;
  step: StepSnapshot;
  segments: SetSegment[];
  actualRpe: number | null;
  startedAt: number | null;
  completedAt: number | null;
  authoredRestSeconds: number;
  adjustedRestSeconds: number;
  actualRestSeconds: number | null;
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
  queue: string[];
  restEndsAt: number | null;
  pausedRestSeconds: number | null;
  authoredRestSeconds: number;
  adjustedRestSeconds: number;
  restFromExecutionId: string | null;
  records: ExecutionRecord[];
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
  modifiedSets: number;
  extraSets: number;
  deferredSets: number;
  skippedSets: number;
  workingVolume: number;
  warmupVolume: number;
  completedDurationSeconds: number;
  totalActualRestSeconds: number;
  averageRpe: number | null;
  quality: number | null;
  detailsAvailable: boolean;
  executions: ExecutionRecord[];
};

export type StoredState = {
  version: 4;
  updatedAt: number;
  session: WorkoutSession | null;
  history: HistoryEntry[];
};

export type SessionMetrics = {
  completedSets: number;
  modifiedSets: number;
  extraSets: number;
  deferredSets: number;
  skippedSets: number;
  workingVolume: number;
  warmupVolume: number;
  completedDurationSeconds: number;
  totalActualRestSeconds: number;
  averageRpe: number | null;
};

export const STORAGE_KEY = "setline:v1";
export const PENDING_SYNC_KEY = "setline:sync-pending";

const workoutIds: WorkoutId[] = [
  "upper",
  "lower",
  "easy-mobility",
  "upper-hard",
  "mobility",
  "legacy-upper-a",
];
const trackingKinds: TrackingKind[] = [
  "weight-reps",
  "reps",
  "duration",
  "weight-duration",
  "completion",
];
const stepTypes: StepType[] = [
  "Preparation",
  "Warm-up",
  "Working",
  "Cardio",
  "Mobility",
  "Cooldown",
  "Check",
];

function isFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

function isNonNegativeNumber(value: unknown): value is number {
  return isFiniteNumber(value) && value >= 0;
}

function isNullableNumber(value: unknown): value is number | null {
  return value === null || isFiniteNumber(value);
}

function isNullableNonNegativeNumber(value: unknown): value is number | null {
  return value === null || isNonNegativeNumber(value);
}

function isNullableString(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function isWorkoutId(value: unknown): value is WorkoutId {
  return workoutIds.includes(value as WorkoutId);
}

function isSegment(value: unknown): value is SetSegment {
  if (!value || typeof value !== "object") return false;
  const segment = value as Partial<SetSegment>;
  return (
    typeof segment.id === "string" &&
    segment.id.length > 0 &&
    isNullableNonNegativeNumber(segment.weight) &&
    isNullableNonNegativeNumber(segment.reps) &&
    isNullableNonNegativeNumber(segment.durationSeconds)
  );
}

function isStepSnapshot(value: unknown): value is StepSnapshot {
  if (!value || typeof value !== "object") return false;
  const step = value as Partial<StepSnapshot>;
  return (
    typeof step.id === "string" &&
    step.id.length > 0 &&
    isNullableString(step.plannedStepId) &&
    typeof step.exercise === "string" &&
    step.exercise.length > 0 &&
    stepTypes.includes(step.setType as StepType) &&
    typeof step.setLabel === "string" &&
    trackingKinds.includes(step.tracking as TrackingKind) &&
    isNullableNonNegativeNumber(step.targetWeight) &&
    isNullableNonNegativeNumber(step.targetReps) &&
    isNullableNonNegativeNumber(step.targetRepsMax) &&
    isNullableNonNegativeNumber(step.targetDurationSeconds) &&
    isNonNegativeNumber(step.restSeconds) &&
    (step.targetRpe === undefined || isNonNegativeNumber(step.targetRpe)) &&
    typeof step.cue === "string" &&
    typeof step.optional === "boolean"
  );
}

function isExecutionRecord(value: unknown): value is ExecutionRecord {
  if (!value || typeof value !== "object") return false;
  const record = value as Partial<ExecutionRecord>;
  return (
    typeof record.id === "string" &&
    record.id.length > 0 &&
    ["planned", "extra"].includes(record.source ?? "") &&
    isNullableString(record.clonedFromId) &&
    isNullableNonNegativeNumber(record.plannedPosition) &&
    isNullableNonNegativeNumber(record.performedPosition) &&
    typeof record.deferred === "boolean" &&
    ["pending", "completed", "skipped"].includes(record.status ?? "") &&
    isStepSnapshot(record.step) &&
    Array.isArray(record.segments) &&
    record.segments.length >= 1 &&
    record.segments.length <= 20 &&
    record.segments.every(isSegment) &&
    isNullableNumber(record.actualRpe) &&
    (record.actualRpe === null || (record.actualRpe >= 0 && record.actualRpe <= 10)) &&
    isNullableNonNegativeNumber(record.startedAt) &&
    isNullableNonNegativeNumber(record.completedAt) &&
    isNonNegativeNumber(record.authoredRestSeconds) &&
    isNonNegativeNumber(record.adjustedRestSeconds) &&
    isNullableNonNegativeNumber(record.actualRestSeconds)
  );
}

function queueMatchesRecords(queue: unknown, records: ExecutionRecord[]) {
  if (
    !Array.isArray(queue) ||
    queue.length !== records.length ||
    !queue.every((id) => typeof id === "string")
  ) {
    return false;
  }
  const ids = new Set(records.map((record) => record.id));
  return (
    ids.size === records.length &&
    new Set(queue).size === queue.length &&
    queue.every((id) => ids.has(id))
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
    !isNonNegativeNumber(session.startedAt) ||
    !isNullableNonNegativeNumber(session.completedAt) ||
    !["active", "rest", "summary"].includes(session.phase ?? "") ||
    !Number.isInteger(session.activeIndex) ||
    !isNullableNonNegativeNumber(session.restEndsAt) ||
    !isNullableNonNegativeNumber(session.pausedRestSeconds) ||
    !isNonNegativeNumber(session.authoredRestSeconds) ||
    !isNonNegativeNumber(session.adjustedRestSeconds) ||
    !isNullableString(session.restFromExecutionId) ||
    !Array.isArray(session.records) ||
    session.records.length < 1 ||
    session.records.length > 2000 ||
    !session.records.every(isExecutionRecord) ||
    !isNullableNumber(session.quality)
  ) {
    return false;
  }
  if (
    !queueMatchesRecords(session.queue, session.records) ||
    (session.activeIndex ?? -1) < 0 ||
    (session.activeIndex ?? session.records.length) >= session.records.length
  ) {
    return false;
  }
  if (
    session.restFromExecutionId !== null &&
    !session.records.some((record) => record.id === session.restFromExecutionId)
  ) {
    return false;
  }

  const template = resolveWorkout(
    session.workoutId as WorkoutId,
    session.weekNumber as number,
    session.dayIndex as number,
  );
  const planned = session.records.filter((record) => record.source === "planned");
  return (
    planned.length === template.steps.length &&
    planned.every((record, index) => {
      const target = template.steps[index];
      return (
        record.step.plannedStepId === target.id &&
        record.plannedPosition === index + 1
      );
    })
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
    isNonNegativeNumber(entry.completedAt) &&
    isNonNegativeNumber(entry.durationSeconds) &&
    isNonNegativeNumber(entry.completedSets) &&
    isNonNegativeNumber(entry.modifiedSets) &&
    isNonNegativeNumber(entry.extraSets) &&
    isNonNegativeNumber(entry.deferredSets) &&
    isNonNegativeNumber(entry.skippedSets) &&
    isNonNegativeNumber(entry.workingVolume) &&
    isNonNegativeNumber(entry.warmupVolume) &&
    isNonNegativeNumber(entry.completedDurationSeconds) &&
    isNonNegativeNumber(entry.totalActualRestSeconds) &&
    isNullableNumber(entry.averageRpe) &&
    isNullableNumber(entry.quality) &&
    typeof entry.detailsAvailable === "boolean" &&
    Array.isArray(entry.executions) &&
    entry.executions.length <= 2000 &&
    entry.executions.every(isExecutionRecord) &&
    (entry.detailsAvailable || entry.executions.length === 0)
  );
}

function snapshotStep(planned: PlannedStep): StepSnapshot {
  return {
    id: planned.id,
    plannedStepId: planned.id,
    exercise: planned.exercise,
    setType: planned.setType,
    setLabel: planned.setLabel,
    tracking: planned.tracking,
    targetWeight: planned.targetWeight,
    targetReps: planned.targetReps,
    targetRepsMax: planned.targetRepsMax,
    targetDurationSeconds: planned.targetDurationSeconds,
    restSeconds: planned.restSeconds,
    targetRpe: planned.targetRpe,
    cue: planned.cue,
    optional: planned.optional ?? false,
  };
}

export function makeInitialSegment(step: StepSnapshot, id: string): SetSegment {
  return {
    id,
    weight:
      step.tracking === "weight-reps" || step.tracking === "weight-duration"
        ? step.targetWeight ?? 0
        : null,
    reps:
      step.tracking === "weight-reps" || step.tracking === "reps"
        ? step.targetReps
        : null,
    durationSeconds:
      step.tracking === "duration" || step.tracking === "weight-duration"
        ? step.targetDurationSeconds
        : null,
  };
}

export function makeExecutionRecord(
  planned: PlannedStep,
  plannedIndex: number,
  startedAt: number | null,
): ExecutionRecord {
  const step = snapshotStep(planned);
  const id = `planned:${planned.id}`;
  return {
    id,
    source: "planned",
    clonedFromId: null,
    plannedPosition: plannedIndex + 1,
    performedPosition: null,
    deferred: false,
    status: "pending",
    step,
    segments: [makeInitialSegment(step, `${id}:segment:1`)],
    actualRpe: null,
    startedAt,
    completedAt: null,
    authoredRestSeconds: planned.restSeconds,
    adjustedRestSeconds: planned.restSeconds,
    actualRestSeconds: null,
  };
}

export function makeWorkoutSession(
  template: WorkoutTemplate,
  weekNumber: number,
  dayIndex: number,
  startedAt = Date.now(),
): WorkoutSession {
  const records = template.steps.map((step, index) =>
    makeExecutionRecord(step, index, index === 0 ? startedAt : null),
  );
  return {
    id: `session-${startedAt}`,
    workoutId: template.id,
    workoutName: template.name,
    weekNumber,
    dayIndex,
    startedAt,
    completedAt: null,
    phase: "active",
    activeIndex: 0,
    queue: records.map((record) => record.id),
    restEndsAt: null,
    pausedRestSeconds: null,
    authoredRestSeconds: 0,
    adjustedRestSeconds: 0,
    restFromExecutionId: null,
    records,
    quality: null,
  };
}

export function getExecution(
  session: WorkoutSession,
  executionId: string | null | undefined,
) {
  return executionId
    ? session.records.find((record) => record.id === executionId) ?? null
    : null;
}

export function getActiveExecution(session: WorkoutSession) {
  return getExecution(session, session.queue[session.activeIndex]);
}

export function makeExtraExecution(
  source: ExecutionRecord,
  executionId: string,
): ExecutionRecord {
  return {
    ...source,
    id: executionId,
    source: "extra",
    clonedFromId: source.id,
    plannedPosition: null,
    performedPosition: null,
    deferred: false,
    status: "pending",
    step: {
      ...source.step,
      id: executionId,
      plannedStepId: null,
      setLabel: `Extra set · ${source.step.setLabel}`,
    },
    segments: source.segments.map((segment, index) => ({
      ...segment,
      id: `${executionId}:segment:${index + 1}`,
    })),
    actualRpe: null,
    startedAt: null,
    completedAt: null,
    actualRestSeconds: null,
  };
}

export function insertExtraExecution(
  session: WorkoutSession,
  source: ExecutionRecord,
  executionId: string,
): WorkoutSession {
  const extra = makeExtraExecution(source, executionId);
  const insertAt =
    session.phase === "rest" ? session.activeIndex : session.activeIndex + 1;
  return {
    ...session,
    queue: [
      ...session.queue.slice(0, insertAt),
      extra.id,
      ...session.queue.slice(insertAt),
    ],
    records: [...session.records, extra],
  };
}

export function deferActiveExecution(
  session: WorkoutSession,
  nextStartedAt: number,
): WorkoutSession {
  if (
    session.phase !== "active" ||
    session.activeIndex >= session.queue.length - 1
  ) {
    return session;
  }
  const queue = [...session.queue];
  const [deferredId] = queue.splice(session.activeIndex, 1);
  queue.push(deferredId);
  const nextId = queue[session.activeIndex];
  return {
    ...session,
    queue,
    records: session.records.map((record) =>
      record.id === deferredId
        ? { ...record, deferred: true, startedAt: null }
        : record.id === nextId && record.startedAt === null
          ? { ...record, startedAt: nextStartedAt }
          : record,
    ),
  };
}

export function startQueuedExecution(
  session: WorkoutSession,
  startedAt: number,
): WorkoutSession {
  const currentId = session.queue[session.activeIndex];
  const previous = getExecution(session, session.restFromExecutionId);
  const actualRestSeconds =
    previous?.completedAt === null || previous?.completedAt === undefined
      ? null
      : Math.max(0, Math.round((startedAt - previous.completedAt) / 1000));
  return {
    ...session,
    phase: "active",
    restEndsAt: null,
    pausedRestSeconds: null,
    records: session.records.map((record) =>
      record.id === currentId
        ? { ...record, startedAt }
        : record.id === previous?.id
          ? { ...record, actualRestSeconds }
          : record,
    ),
    restFromExecutionId: null,
  };
}

export function segmentVolume(segment: SetSegment) {
  return (segment.weight ?? 0) * (segment.reps ?? 0);
}

export function executionVolume(record: ExecutionRecord) {
  return record.segments.reduce((total, segment) => total + segmentVolume(segment), 0);
}

export function executionDuration(record: ExecutionRecord) {
  return record.segments.reduce(
    (total, segment) => total + (segment.durationSeconds ?? 0),
    0,
  );
}

export function executionIsValid(record: ExecutionRecord | null | undefined) {
  if (!record) return false;
  if (record.step.tracking === "completion") return true;
  return record.segments.every((segment) => {
    if (record.step.tracking === "reps") return (segment.reps ?? 0) > 0;
    if (record.step.tracking === "duration") {
      return (segment.durationSeconds ?? 0) > 0;
    }
    if (record.step.tracking === "weight-duration") {
      return (segment.weight ?? 0) >= 0 && (segment.durationSeconds ?? 0) > 0;
    }
    return (segment.weight ?? 0) >= 0 && (segment.reps ?? 0) > 0;
  });
}

export function executionIsModified(record: ExecutionRecord) {
  if (record.source === "extra" || record.deferred || record.segments.length !== 1) {
    return true;
  }
  const segment = record.segments[0];
  const step = record.step;
  if (step.tracking === "weight-reps") {
    return (
      (segment.weight ?? 0) !== (step.targetWeight ?? 0) ||
      segment.reps !== step.targetReps
    );
  }
  if (step.tracking === "reps") return segment.reps !== step.targetReps;
  if (step.tracking === "duration" || step.tracking === "weight-duration") {
    return (
      segment.durationSeconds !== step.targetDurationSeconds ||
      (step.tracking === "weight-duration" &&
        (segment.weight ?? 0) !== (step.targetWeight ?? 0))
    );
  }
  return false;
}

export function getSessionMetrics(session: WorkoutSession): SessionMetrics {
  let workingVolume = 0;
  let warmupVolume = 0;
  let completedDurationSeconds = 0;
  let totalActualRestSeconds = 0;
  const rpes: number[] = [];
  const resolved = session.records.filter((record) => record.status !== "pending");

  for (const record of resolved) {
    if (record.status !== "completed") continue;
    const volume = executionVolume(record);
    if (record.step.setType === "Warm-up" || record.step.setType === "Preparation") {
      warmupVolume += volume;
    } else if (record.step.setType === "Working") {
      workingVolume += volume;
    }
    completedDurationSeconds += executionDuration(record);
    totalActualRestSeconds += record.actualRestSeconds ?? 0;
    if (record.actualRpe !== null) rpes.push(record.actualRpe);
  }

  return {
    completedSets: resolved.filter((record) => record.status === "completed").length,
    modifiedSets: resolved.filter(
      (record) => record.status === "completed" && executionIsModified(record),
    ).length,
    extraSets: resolved.filter((record) => record.source === "extra").length,
    deferredSets: resolved.filter((record) => record.deferred).length,
    skippedSets: resolved.filter((record) => record.status === "skipped").length,
    workingVolume,
    warmupVolume,
    completedDurationSeconds,
    totalActualRestSeconds,
    averageRpe: rpes.length
      ? rpes.reduce((total, value) => total + value, 0) / rpes.length
      : null,
  };
}

type V3Record = {
  setId?: unknown;
  status?: unknown;
  actualWeight?: unknown;
  actualReps?: unknown;
  actualDurationSeconds?: unknown;
  actualRpe?: unknown;
  completedAt?: unknown;
};

type V3Session = {
  id?: unknown;
  workoutId?: unknown;
  workoutName?: unknown;
  weekNumber?: unknown;
  dayIndex?: unknown;
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

type V3History = {
  id?: unknown;
  workoutId?: unknown;
  workoutName?: unknown;
  weekNumber?: unknown;
  completedAt?: unknown;
  durationSeconds?: unknown;
  completedSets?: unknown;
  skippedSets?: unknown;
  workingVolume?: unknown;
  warmupVolume?: unknown;
  completedDurationSeconds?: unknown;
  averageRpe?: unknown;
  quality?: unknown;
};

function migrateV3Record(
  value: unknown,
  planned: PlannedStep,
  index: number,
  sessionStartedAt: number,
): ExecutionRecord | null {
  if (!value || typeof value !== "object") return null;
  const legacy = value as V3Record;
  if (
    legacy.setId !== planned.id ||
    !["pending", "completed", "skipped"].includes(String(legacy.status)) ||
    !isNullableNonNegativeNumber(legacy.actualWeight) ||
    !isNullableNonNegativeNumber(legacy.actualReps) ||
    !isNullableNonNegativeNumber(legacy.actualDurationSeconds) ||
    !isNullableNumber(legacy.actualRpe) ||
    !isNullableNonNegativeNumber(legacy.completedAt)
  ) {
    return null;
  }
  const record = makeExecutionRecord(planned, index, index === 0 ? sessionStartedAt : null);
  record.status = legacy.status as ExecutionStatus;
  record.actualRpe = legacy.actualRpe;
  record.completedAt = legacy.completedAt;
  record.performedPosition =
    record.status === "pending" ? null : index + 1;
  record.segments = [
    {
      id: `${record.id}:segment:1`,
      weight: legacy.actualWeight,
      reps: legacy.actualReps,
      durationSeconds: legacy.actualDurationSeconds,
    },
  ];
  return record;
}

function migrateV3Session(value: unknown): WorkoutSession | null | undefined {
  if (value === null) return null;
  if (!value || typeof value !== "object") return undefined;
  const legacy = value as V3Session;
  if (
    typeof legacy.id !== "string" ||
    !isWorkoutId(legacy.workoutId) ||
    typeof legacy.workoutName !== "string" ||
    !Number.isInteger(legacy.weekNumber) ||
    !Number.isInteger(legacy.dayIndex) ||
    !isNonNegativeNumber(legacy.startedAt) ||
    !isNullableNonNegativeNumber(legacy.completedAt) ||
    !["active", "rest", "summary"].includes(String(legacy.phase)) ||
    !Number.isInteger(legacy.activeIndex) ||
    !isNullableNonNegativeNumber(legacy.restEndsAt) ||
    !isNullableNonNegativeNumber(legacy.pausedRestSeconds) ||
    !isNonNegativeNumber(legacy.plannedRestSeconds) ||
    !Array.isArray(legacy.records) ||
    !isNullableNumber(legacy.quality)
  ) {
    return undefined;
  }
  const template = resolveWorkout(
    legacy.workoutId,
    legacy.weekNumber as number,
    legacy.dayIndex as number,
  );
  if (legacy.records.length !== template.steps.length) return undefined;
  const records = legacy.records.map((record, index) =>
    migrateV3Record(record, template.steps[index], index, legacy.startedAt as number),
  );
  if (records.some((record) => record === null)) return undefined;
  const typedRecords = records as ExecutionRecord[];
  const activeIndex = legacy.activeIndex as number;
  const previous = typedRecords[Math.max(0, activeIndex - 1)] ?? null;
  return {
    id: legacy.id,
    workoutId: legacy.workoutId,
    workoutName: legacy.workoutName,
    weekNumber: legacy.weekNumber as number,
    dayIndex: legacy.dayIndex as number,
    startedAt: legacy.startedAt,
    completedAt: legacy.completedAt,
    phase: legacy.phase as SessionPhase,
    activeIndex,
    queue: typedRecords.map((record) => record.id),
    restEndsAt: legacy.restEndsAt,
    pausedRestSeconds: legacy.pausedRestSeconds,
    authoredRestSeconds: legacy.plannedRestSeconds,
    adjustedRestSeconds: legacy.plannedRestSeconds,
    restFromExecutionId:
      legacy.phase === "rest" && previous ? previous.id : null,
    records: typedRecords,
    quality: legacy.quality,
  };
}

function migrateSummaryHistory(
  value: unknown,
  fallback: {
    workoutId: WorkoutId;
    workoutName: string;
    weekNumber: number;
  },
): HistoryEntry[] | undefined {
  if (!Array.isArray(value) || value.length > 500) return undefined;
  const entries = value.map((item) => {
    if (!item || typeof item !== "object") return null;
    const legacy = item as V3History;
    const workoutId = isWorkoutId(legacy.workoutId)
      ? legacy.workoutId
      : fallback.workoutId;
    const workoutName =
      typeof legacy.workoutName === "string"
        ? legacy.workoutName
        : fallback.workoutName;
    const weekNumber = Number.isInteger(legacy.weekNumber)
      ? (legacy.weekNumber as number)
      : fallback.weekNumber;
    if (
      typeof legacy.id !== "string" ||
      !isNonNegativeNumber(legacy.completedAt) ||
      !isNonNegativeNumber(legacy.durationSeconds) ||
      !isNonNegativeNumber(legacy.completedSets) ||
      !isNonNegativeNumber(legacy.skippedSets) ||
      !isNonNegativeNumber(legacy.workingVolume) ||
      !isNonNegativeNumber(legacy.warmupVolume) ||
      !isNullableNumber(legacy.averageRpe) ||
      !isNullableNumber(legacy.quality)
    ) {
      return null;
    }
    return {
      id: legacy.id,
      workoutId,
      workoutName,
      weekNumber,
      completedAt: legacy.completedAt,
      durationSeconds: legacy.durationSeconds,
      completedSets: legacy.completedSets,
      modifiedSets: 0,
      extraSets: 0,
      deferredSets: 0,
      skippedSets: legacy.skippedSets,
      workingVolume: legacy.workingVolume,
      warmupVolume: legacy.warmupVolume,
      completedDurationSeconds: isNonNegativeNumber(legacy.completedDurationSeconds)
        ? legacy.completedDurationSeconds
        : 0,
      totalActualRestSeconds: 0,
      averageRpe: legacy.averageRpe,
      quality: legacy.quality,
      detailsAvailable: false,
      executions: [],
    } satisfies HistoryEntry;
  });
  return entries.some((entry) => entry === null)
    ? undefined
    : (entries as HistoryEntry[]);
}

function migrateV1OrV2Session(value: unknown): WorkoutSession | null | undefined {
  if (value === null) return null;
  if (!value || typeof value !== "object") return undefined;
  const legacy = value as V3Session;
  return migrateV3Session({
    ...legacy,
    workoutId: "legacy-upper-a",
    workoutName: "Upper A · legacy sample",
    weekNumber: 1,
    dayIndex: 0,
    records:
      Array.isArray(legacy.records) && legacy.records.length === LEGACY_UPPER_STEPS.length
        ? legacy.records.map((record) =>
            record && typeof record === "object"
              ? { actualDurationSeconds: null, ...record }
              : record,
          )
        : legacy.records,
  });
}

export function emptyStoredState(): StoredState {
  return {
    version: 4,
    updatedAt: 0,
    session: null,
    history: [],
  };
}

export function parseStoredState(
  value: unknown,
  migrationTime = Date.now(),
): StoredState | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as {
    version?: unknown;
    updatedAt?: unknown;
    session?: unknown;
    history?: unknown;
  };

  if (candidate.version === 4) {
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
      !isNonNegativeNumber(candidate.updatedAt)
    ) {
      return null;
    }
    return {
      version: 4,
      updatedAt: candidate.updatedAt,
      session,
      history,
    };
  }

  if (candidate.version === 3) {
    const session = migrateV3Session(candidate.session);
    const history = migrateSummaryHistory(candidate.history, {
      workoutId: "legacy-upper-a",
      workoutName: "Legacy workout",
      weekNumber: 1,
    });
    if (
      session === undefined ||
      history === undefined ||
      !isNonNegativeNumber(candidate.updatedAt)
    ) {
      return null;
    }
    return {
      version: 4,
      updatedAt: candidate.updatedAt,
      session,
      history,
    };
  }

  if (candidate.version === 1 || candidate.version === 2) {
    const session = migrateV1OrV2Session(candidate.session);
    const history = migrateSummaryHistory(candidate.history, {
      workoutId: "legacy-upper-a",
      workoutName: "Upper A · legacy sample",
      weekNumber: 1,
    });
    if (session === undefined || history === undefined) return null;
    return {
      version: 4,
      updatedAt:
        candidate.version === 2 &&
        isNonNegativeNumber(candidate.updatedAt)
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
    version: 4,
    updatedAt: Math.max(Date.now(), current.updatedAt + 1),
  };
}
