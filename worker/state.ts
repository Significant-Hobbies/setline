import { createAuth, type SetlineBindings } from "./auth";
import { parseStoredState, type StoredState } from "../app/lib/workout-state";

const MAX_STATE_BYTES = 512 * 1024;
const MAX_HISTORY_ENTRIES = 500;
const MAX_FUTURE_SKEW_MS = 5 * 60 * 1000;

type StateRow = {
  payload: string;
  updated_at: number;
};

type ReadResult =
  | { ok: true; value: unknown }
  | { ok: false; status: 400 | 413 | 415; message: string };

export function parseStateEnvelope(value: unknown): StoredState | null {
  const state = parseStoredState(value);
  if (
    !state ||
    state.history.length > MAX_HISTORY_ENTRIES ||
    state.updatedAt > Date.now() + MAX_FUTURE_SKEW_MS
  ) {
    return null;
  }
  return state;
}

async function readJsonWithLimit(request: Request): Promise<ReadResult> {
  if (!request.headers.get("content-type")?.toLowerCase().startsWith("application/json")) {
    return { ok: false, status: 415, message: "Expected application/json." };
  }

  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > MAX_STATE_BYTES) {
    return { ok: false, status: 413, message: "Workout state is too large." };
  }
  if (!request.body) {
    return { ok: false, status: 400, message: "Workout state is required." };
  }

  const reader = request.body.getReader();
  const decoder = new TextDecoder();
  let total = 0;
  let text = "";

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > MAX_STATE_BYTES) {
      await reader.cancel();
      return { ok: false, status: 413, message: "Workout state is too large." };
    }
    text += decoder.decode(value, { stream: true });
  }
  text += decoder.decode();

  try {
    return { ok: true, value: JSON.parse(text) };
  } catch {
    return { ok: false, status: 400, message: "Workout state must be valid JSON." };
  }
}

function parseStoredRow(row: StateRow | null) {
  if (!row) return null;
  try {
    const state = JSON.parse(row.payload) as unknown;
    return parseStateEnvelope(state);
  } catch {
    return null;
  }
}

function json(payload: unknown, status = 200) {
  return Response.json(payload, { status });
}

async function resolveUserId(request: Request, env: SetlineBindings) {
  const authSession = await createAuth(env, request.url).api.getSession({
    headers: request.headers,
  });
  return authSession?.user?.id ?? null;
}

export async function handlePrivateState(request: Request, env: SetlineBindings) {
  const userId = await resolveUserId(request, env);
  if (!userId) {
    return json({ code: "UNAUTHORIZED", message: "Sign in to continue." }, 401);
  }

  if (request.method === "GET") {
    const row = await env.DB.prepare(
      "SELECT payload, updated_at FROM workout_state WHERE user_id = ?",
    )
      .bind(userId)
      .first<StateRow>();
    return json({ state: parseStoredRow(row) });
  }

  if (request.method !== "PUT") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { Allow: "GET, PUT" },
    });
  }

  const parsed = await readJsonWithLimit(request);
  if (!parsed.ok) {
    return json({ code: "INVALID_STATE", message: parsed.message }, parsed.status);
  }
  const incomingState = parseStateEnvelope(parsed.value);
  if (!incomingState) {
    return json(
      {
        code: "INVALID_STATE",
        message:
          "Workout state has an unsupported version, shape, or exercise order.",
      },
      400,
    );
  }

  const currentRow = await env.DB.prepare(
    "SELECT payload, updated_at FROM workout_state WHERE user_id = ?",
  )
    .bind(userId)
    .first<StateRow>();
  if (currentRow && currentRow.updated_at >= incomingState.updatedAt) {
    return json(
      {
        code: "STALE_STATE",
        message: "A newer workout state is already stored.",
        state: parseStoredRow(currentRow),
      },
      409,
    );
  }

  const now = Date.now();
  const writeResult = await env.DB.prepare(
    `INSERT INTO workout_state (user_id, payload, updated_at, created_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       payload = excluded.payload,
       updated_at = excluded.updated_at
     WHERE excluded.updated_at > workout_state.updated_at`,
  )
    .bind(userId, JSON.stringify(incomingState), incomingState.updatedAt, now)
    .run();

  if (writeResult.meta.changes === 0) {
    const newerRow = await env.DB.prepare(
      "SELECT payload, updated_at FROM workout_state WHERE user_id = ?",
    )
      .bind(userId)
      .first<StateRow>();
    return json(
      {
        code: "STALE_STATE",
        message: "A newer workout state is already stored.",
        state: parseStoredRow(newerRow),
      },
      409,
    );
  }

  return json({ state: incomingState });
}
