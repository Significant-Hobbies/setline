import { deriveHistoryAnalytics } from "../app/lib/history-analytics";
import {
  PROGRAMME,
  PROGRAMME_SCHEDULE,
  resolveWorkout,
  type BuiltInWorkoutId,
} from "../app/lib/programme";
import {
  parseStoredState,
  type HistoryEntry,
  type StoredState,
} from "../app/lib/workout-state";
import { createAuth, type SetlineBindings } from "./auth";

const TOKEN_PREFIX = "setline_read_";
const MAX_LIMIT = 100;

type StateRow = { payload: string };
type TokenRow = {
  id: string;
  name: string;
  token_hint: string;
  created_at: number;
};

function json(payload: unknown, status = 200) {
  return Response.json(payload, { status });
}

function toHex(bytes: Uint8Array) {
  return [...bytes].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export function readBearerToken(header: string | null): string | null {
  if (!header?.startsWith("Bearer ")) return null;
  const token = header.slice("Bearer ".length).trim();
  return token.startsWith(TOKEN_PREFIX) && /^[A-Za-z0-9_-]+$/.test(token)
    ? token
    : null;
}

export async function hashReadToken(token: string) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(token),
  );
  return toHex(new Uint8Array(digest));
}

export function createReadToken() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const encoded = btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
  return `${TOKEN_PREFIX}${encoded}`;
}

async function resolveSessionUserId(request: Request, env: SetlineBindings) {
  const session = await createAuth(env, request.url).api.getSession({
    headers: request.headers,
  });
  return session?.user?.id ?? null;
}

async function resolveReadUserId(request: Request, env: SetlineBindings) {
  const token = readBearerToken(request.headers.get("Authorization"));
  if (!token) return null;
  const row = await env.DB.prepare(
    `SELECT user_id FROM mcp_read_tokens
     WHERE token_hash = ? AND revoked_at IS NULL`,
  )
    .bind(await hashReadToken(token))
    .first<{ user_id: string }>();
  return row?.user_id ?? null;
}

function parseState(row: StateRow | null): StoredState {
  if (row) {
    try {
      const state = parseStoredState(JSON.parse(row.payload) as unknown);
      if (state) return state;
    } catch {
      // Treat corrupt or unsupported cloud state as unavailable, never as partial data.
    }
  }
  return {
    version: 6,
    updatedAt: 0,
    session: null,
    history: [],
    customWorkouts: [],
    customProgramme: null,
  };
}

async function readState(env: SetlineBindings, userId: string) {
  const row = await env.DB.prepare(
    "SELECT payload FROM workout_state WHERE user_id = ?",
  )
    .bind(userId)
    .first<StateRow>();
  return parseState(row);
}

function boundedText(value: string | null, maximum = 160) {
  const trimmed = value?.trim();
  return trimmed ? trimmed.slice(0, maximum) : null;
}

function page(url: URL) {
  const rawLimit = Number(url.searchParams.get("limit"));
  const rawOffset = Number(url.searchParams.get("offset"));
  return {
    limit:
      Number.isInteger(rawLimit) && rawLimit > 0
        ? Math.min(rawLimit, MAX_LIMIT)
        : 30,
    offset:
      Number.isInteger(rawOffset) && rawOffset >= 0
        ? Math.min(rawOffset, 10_000)
        : 0,
  };
}

function pagination(total: number, limit: number, offset: number) {
  return {
    limit,
    offset,
    total,
    nextOffset: offset + limit < total ? offset + limit : null,
  };
}

function builtInTemplates() {
  const seen = new Set<string>();
  return PROGRAMME_SCHEDULE.flatMap((schedule) => {
    if (seen.has(schedule.workoutId)) return [];
    seen.add(schedule.workoutId);
    const workout = resolveWorkout(
      schedule.workoutId as BuiltInWorkoutId,
      1,
      schedule.dayIndex,
    );
    return [
      {
        ...workout,
        provenance: "authored" as const,
        representativeWeek: 1,
      },
    ];
  });
}

function bundledProgramme() {
  return {
    kind: "bundled" as const,
    provenance: "authored" as const,
    programme: PROGRAMME,
    schedule: PROGRAMME_SCHEDULE,
    note: "Week-specific targets remain authored; template detail is represented at week 1.",
  };
}

function customProgramme(state: StoredState) {
  return {
    kind: "custom" as const,
    provenance: "authored" as const,
    programme: state.customProgramme,
    templates: state.customWorkouts,
  };
}

function historySummary(entry: HistoryEntry) {
  return {
    id: entry.id,
    workoutId: entry.workoutId,
    workoutName: entry.workoutName,
    weekNumber: entry.weekNumber,
    completedAt: entry.completedAt,
    durationSeconds: entry.durationSeconds,
    completedSets: entry.completedSets,
    modifiedSets: entry.modifiedSets,
    extraSets: entry.extraSets,
    deferredSets: entry.deferredSets,
    skippedSets: entry.skippedSets,
    workingVolume: entry.workingVolume,
    warmupVolume: entry.warmupVolume,
    completedDurationSeconds: entry.completedDurationSeconds,
    totalActualRestSeconds: entry.totalActualRestSeconds,
    averageRpe: entry.averageRpe,
    quality: entry.quality,
    detailsAvailable: entry.detailsAvailable,
    provenance: "recorded" as const,
  };
}

function dateBoundary(value: string | null, end = false) {
  if (!value || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
  const parsed = Date.parse(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed) ? parsed + (end ? 86_400_000 : 0) : null;
}

export function filterHistory(history: HistoryEntry[], url: URL) {
  const start = dateBoundary(url.searchParams.get("start"));
  const end = dateBoundary(url.searchParams.get("end"), true);
  const workout = boundedText(
    url.searchParams.get("workout"),
  )?.toLocaleLowerCase();
  const exercise = boundedText(
    url.searchParams.get("exercise"),
  )?.toLocaleLowerCase();
  return [...history]
    .sort((left, right) => right.completedAt - left.completedAt)
    .filter((entry) => {
      if (start !== null && entry.completedAt < start) return false;
      if (end !== null && entry.completedAt >= end) return false;
      if (
        workout &&
        !`${entry.workoutId} ${entry.workoutName}`
          .toLocaleLowerCase()
          .includes(workout)
      ) {
        return false;
      }
      if (
        exercise &&
        !entry.executions.some((record) =>
          record.step.exercise.toLocaleLowerCase().includes(exercise),
        )
      ) {
        return false;
      }
      return true;
    });
}

export async function handleMcpTokenManagement(
  request: Request,
  env: SetlineBindings,
) {
  const userId = await resolveSessionUserId(request, env);
  if (!userId)
    return json({ code: "UNAUTHORIZED", message: "Sign in to continue." }, 401);
  const url = new URL(request.url);
  if (url.pathname === "/api/app/mcp-tokens" && request.method === "GET") {
    const result = await env.DB.prepare(
      `SELECT id, name, token_hint, created_at FROM mcp_read_tokens
       WHERE user_id = ? AND revoked_at IS NULL ORDER BY created_at DESC LIMIT 20`,
    )
      .bind(userId)
      .all<TokenRow>();
    return json(
      result.results.map((row) => ({
        id: row.id,
        name: row.name,
        tokenHint: row.token_hint,
        createdAt: row.created_at,
      })),
    );
  }
  if (url.pathname === "/api/app/mcp-tokens" && request.method === "POST") {
    const body = await request
      .json<Record<string, unknown>>()
      .catch((): Record<string, unknown> => ({}));
    const requestedName = typeof body.name === "string" ? body.name.trim() : "";
    const name = requestedName.slice(0, 50) || "ChatGPT read access";
    const token = createReadToken();
    const id = crypto.randomUUID();
    const createdAt = Date.now();
    await env.DB.prepare(
      `INSERT INTO mcp_read_tokens
        (id, user_id, name, token_hash, token_hint, created_at, revoked_at)
       VALUES (?, ?, ?, ?, ?, ?, NULL)`,
    )
      .bind(
        id,
        userId,
        name,
        await hashReadToken(token),
        token.slice(0, 24),
        createdAt,
      )
      .run();
    return json(
      { id, name, token, tokenHint: token.slice(0, 24), createdAt },
      201,
    );
  }
  const match = url.pathname.match(/^\/api\/app\/mcp-tokens\/([^/]+)$/);
  if (match && request.method === "DELETE") {
    const result = await env.DB.prepare(
      `UPDATE mcp_read_tokens SET revoked_at = ?
       WHERE id = ? AND user_id = ? AND revoked_at IS NULL`,
    )
      .bind(Date.now(), decodeURIComponent(match[1]), userId)
      .run();
    return result.meta.changes
      ? new Response(null, { status: 204 })
      : json({ code: "NOT_FOUND", message: "Read token not found." }, 404);
  }
  return new Response("Method Not Allowed", {
    status: 405,
    headers: { Allow: "GET, POST, DELETE" },
  });
}

export async function handleMcpRead(request: Request, env: SetlineBindings) {
  if (request.method !== "GET") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { Allow: "GET" },
    });
  }
  const userId = await resolveReadUserId(request, env);
  if (!userId) {
    return json(
      { code: "UNAUTHORIZED", message: "Provide a valid Setline read token." },
      401,
    );
  }
  const url = new URL(request.url);
  const state = await readState(env, userId);

  if (url.pathname === "/api/mcp/programme") {
    const requested = url.searchParams.get("kind") ?? "current";
    const useCustom =
      requested === "custom" ||
      (requested === "current" && state.customProgramme?.enabled === true);
    return json({
      schemaVersion: "1",
      data: useCustom ? customProgramme(state) : bundledProgramme(),
    });
  }

  if (url.pathname === "/api/mcp/templates") {
    const { limit, offset } = page(url);
    const items = [
      ...builtInTemplates(),
      ...state.customWorkouts.map((template) => ({
        ...template,
        provenance: "authored" as const,
      })),
    ];
    return json({
      schemaVersion: "1",
      items: items.slice(offset, offset + limit),
      page: pagination(items.length, limit, offset),
    });
  }

  if (url.pathname === "/api/mcp/history") {
    const { limit, offset } = page(url);
    const filtered = filterHistory(state.history, url);
    return json({
      schemaVersion: "1",
      items: filtered.slice(offset, offset + limit).map(historySummary),
      page: pagination(filtered.length, limit, offset),
    });
  }

  const sessionMatch = url.pathname.match(/^\/api\/mcp\/history\/([^/]+)$/);
  if (sessionMatch) {
    const id = decodeURIComponent(sessionMatch[1]);
    if (!/^[A-Za-z0-9:_-]{1,120}$/.test(id)) {
      return json(
        { code: "NOT_FOUND", message: "Workout session not found." },
        404,
      );
    }
    const entry = state.history.find((candidate) => candidate.id === id);
    return entry
      ? json({ schemaVersion: "1", data: { ...entry, provenance: "recorded" } })
      : json({ code: "NOT_FOUND", message: "Workout session not found." }, 404);
  }

  if (url.pathname === "/api/mcp/progress") {
    const exercise = boundedText(
      url.searchParams.get("exercise"),
    )?.toLocaleLowerCase();
    const workout = boundedText(
      url.searchParams.get("workout"),
    )?.toLocaleLowerCase();
    const analytics = deriveHistoryAnalytics(state.history);
    return json({
      schemaVersion: "1",
      provenance: "calculated-from-recorded-history",
      data: {
        overview: analytics.overview,
        exercises: exercise
          ? analytics.exercises.filter((item) =>
              `${item.id} ${item.name}`.toLocaleLowerCase().includes(exercise),
            )
          : analytics.exercises,
        workouts: workout
          ? analytics.workouts.filter((item) =>
              `${item.workoutId} ${item.workoutName}`
                .toLocaleLowerCase()
                .includes(workout),
            )
          : analytics.workouts,
        programmeWeeks: analytics.programmeWeeks,
      },
    });
  }

  return json({ code: "NOT_FOUND", message: "Read route not found." }, 404);
}
