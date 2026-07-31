import {
  parseStoredState,
  type StoredState,
  type WorkoutSession,
} from "./workout-state";

export const WORKOUT_DATA_FORMAT = "setline-workout-data";
export const WORKOUT_DATA_FORMAT_VERSION = 1;
export const MAX_WORKOUT_DATA_FILE_BYTES = 2 * 1024 * 1024;

export type WorkoutDataFileMetadata = {
  name: string;
  size: number;
  type?: string;
};

export type WorkoutDataEnvelope = {
  format: typeof WORKOUT_DATA_FORMAT;
  formatVersion: typeof WORKOUT_DATA_FORMAT_VERSION;
  exportedAt: string;
  state: StoredState;
};

export type WorkoutDataImportPreview = {
  exportedAt: string;
  state: StoredState;
  activeSession: {
    workoutId: WorkoutSession["workoutId"];
    workoutName: string;
    weekNumber: number;
    phase: WorkoutSession["phase"];
    completedExecutions: number;
    totalExecutions: number;
  } | null;
  historyCount: number;
  customWorkoutCount: number;
  latestWorkout: {
    workoutName: string;
    completedAt: number;
  } | null;
};

export type WorkoutDataImportResult =
  | { status: "ok"; preview: WorkoutDataImportPreview }
  | { status: "error"; message: string };

const envelopeKeys = ["exportedAt", "format", "formatVersion", "state"];
const acceptedJsonTypes = new Set(["", "application/json", "text/json"]);

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function isIsoTimestamp(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && new Date(timestamp).toISOString() === value;
}

export function validateWorkoutDataFileMetadata(
  file: WorkoutDataFileMetadata,
): string | null {
  if (!file.name.toLowerCase().endsWith(".json")) {
    return "Choose a Setline .json file.";
  }
  if (
    file.type !== undefined &&
    !acceptedJsonTypes.has(file.type.toLowerCase())
  ) {
    return "Choose a JSON file exported by Setline.";
  }
  if (!Number.isFinite(file.size) || file.size <= 0) {
    return "The selected file is empty.";
  }
  if (file.size > MAX_WORKOUT_DATA_FILE_BYTES) {
    return "The selected file is larger than Setline’s 2 MiB import limit.";
  }
  return null;
}

export function createWorkoutDataEnvelope(
  state: StoredState,
  exportedAt = new Date(),
): WorkoutDataEnvelope {
  return {
    format: WORKOUT_DATA_FORMAT,
    formatVersion: WORKOUT_DATA_FORMAT_VERSION,
    exportedAt: exportedAt.toISOString(),
    state,
  };
}

export function serializeWorkoutData(
  state: StoredState,
  exportedAt = new Date(),
) {
  const envelope = createWorkoutDataEnvelope(state, exportedAt);
  return {
    fileName: `setline-workout-data-${envelope.exportedAt.slice(0, 10)}.json`,
    json: `${JSON.stringify(envelope, null, 2)}\n`,
  };
}

function buildImportPreview(
  state: StoredState,
  exportedAt: string,
): WorkoutDataImportPreview {
  const activeSession = state.session;
  const latestHistoryEntry = state.history.reduce(
    (latest, entry) =>
      latest === null || entry.completedAt > latest.completedAt ? entry : latest,
    null as StoredState["history"][number] | null,
  );
  return {
    exportedAt,
    state,
    activeSession: activeSession
      ? {
          workoutId: activeSession.workoutId,
          workoutName: activeSession.workoutName,
          weekNumber: activeSession.weekNumber,
          phase: activeSession.phase,
          completedExecutions: activeSession.records.filter(
            (record) => record.status !== "pending",
          ).length,
          totalExecutions: activeSession.records.length,
        }
      : null,
    historyCount: state.history.length,
    customWorkoutCount: state.customWorkouts.length,
    latestWorkout: latestHistoryEntry
      ? {
          workoutName: latestHistoryEntry.workoutName,
          completedAt: latestHistoryEntry.completedAt,
        }
      : null,
  };
}

export function parseWorkoutDataImport(
  raw: string,
  importTime = Date.now(),
): WorkoutDataImportResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw) as unknown;
  } catch {
    return {
      status: "error",
      message: "This file is not valid JSON.",
    };
  }

  if (!isRecord(parsed)) {
    return {
      status: "error",
      message: "This file is not a Setline workout-data export.",
    };
  }
  const keys = Object.keys(parsed).sort();
  if (
    keys.length !== envelopeKeys.length ||
    !keys.every((key, index) => key === envelopeKeys[index])
  ) {
    return {
      status: "error",
      message: "This file has an unsupported Setline transfer shape.",
    };
  }
  if (parsed.format !== WORKOUT_DATA_FORMAT) {
    return {
      status: "error",
      message: "This file is not a Setline workout-data export.",
    };
  }
  if (parsed.formatVersion !== WORKOUT_DATA_FORMAT_VERSION) {
    return {
      status: "error",
      message: "This Setline export version is not supported.",
    };
  }
  if (!isIsoTimestamp(parsed.exportedAt)) {
    return {
      status: "error",
      message: "This Setline export has an invalid export time.",
    };
  }

  const state = parseStoredState(parsed.state, importTime);
  if (!state) {
    return {
      status: "error",
      message:
        "This Setline export contains invalid workout data or exercise order.",
    };
  }
  return {
    status: "ok",
    preview: buildImportPreview(state, parsed.exportedAt),
  };
}

export function activateImportedWorkoutData(
  importedState: StoredState,
  currentState: StoredState,
  activatedAt = Date.now(),
): StoredState {
  return {
    ...importedState,
    updatedAt: Math.max(activatedAt, currentState.updatedAt + 1),
  };
}
