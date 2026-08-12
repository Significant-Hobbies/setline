import { createAuth, type SetlineBindings } from "./auth";

const MAX_STATE_BYTES = 512 * 1024;

type NativeStateRow = {
  payload: string;
  revision: number;
};

type NativeStateEnvelope = {
  document: Record<string, unknown>;
  baseRevision: number | null;
};

function json(payload: unknown, status = 200) {
  return Response.json(payload, { status });
}

export function parseNativeStateEnvelope(
  value: unknown,
): NativeStateEnvelope | null {
  if (!value || typeof value !== "object") return null;
  const candidate = value as Record<string, unknown>;
  if (!candidate.document || typeof candidate.document !== "object")
    return null;
  const document = candidate.document as Record<string, unknown>;
  if (document.schemaVersion !== 1) return null;
  const baseRevision = candidate.baseRevision;
  if (
    baseRevision !== null &&
    (!Number.isSafeInteger(baseRevision) || Number(baseRevision) < 0)
  ) {
    return null;
  }
  return { document, baseRevision: baseRevision as number | null };
}

async function resolveUserId(request: Request, env: SetlineBindings) {
  const session = await createAuth(env, request.url).api.getSession({
    headers: request.headers,
  });
  return session?.user?.id ?? null;
}

function parseRow(row: NativeStateRow | null) {
  if (!row) return null;
  try {
    const document = JSON.parse(row.payload) as unknown;
    if (!document || typeof document !== "object") return null;
    return { document, revision: row.revision };
  } catch {
    return null;
  }
}

export async function handleNativeState(
  request: Request,
  env: SetlineBindings,
) {
  const userId = await resolveUserId(request, env);
  if (!userId) {
    return json({ code: "UNAUTHORIZED", message: "Sign in to continue." }, 401);
  }

  if (request.method === "GET") {
    const row = await env.DB.prepare(
      "SELECT payload, revision FROM native_workout_state WHERE user_id = ?",
    )
      .bind(userId)
      .first<NativeStateRow>();
    return json({ state: parseRow(row) });
  }

  if (request.method !== "PUT") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: { Allow: "GET, PUT" },
    });
  }

  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > MAX_STATE_BYTES) {
    return json(
      { code: "STATE_TOO_LARGE", message: "Workout state is too large." },
      413,
    );
  }
  const text = await request.text();
  if (new TextEncoder().encode(text).byteLength > MAX_STATE_BYTES) {
    return json(
      { code: "STATE_TOO_LARGE", message: "Workout state is too large." },
      413,
    );
  }
  const envelope = parseNativeStateEnvelope(
    (() => {
      try {
        return JSON.parse(text) as unknown;
      } catch {
        return null;
      }
    })(),
  );
  if (!envelope) {
    return json(
      { code: "INVALID_STATE", message: "Native workout state is invalid." },
      400,
    );
  }

  const payload = JSON.stringify(envelope.document);
  const now = Date.now();
  if (envelope.baseRevision === null) {
    const result = await env.DB.prepare(
      `INSERT OR IGNORE INTO native_workout_state
       (user_id, payload, revision, created_at, updated_at)
       VALUES (?, ?, 1, ?, ?)`,
    )
      .bind(userId, payload, now, now)
      .run();
    if (result.meta.changes > 0) {
      return json({ state: { document: envelope.document, revision: 1 } });
    }
  } else {
    const nextRevision = envelope.baseRevision + 1;
    const row = await env.DB.prepare(
      `UPDATE native_workout_state
       SET payload = ?, revision = ?, updated_at = ?
       WHERE user_id = ? AND revision = ?
       RETURNING payload, revision`,
    )
      .bind(payload, nextRevision, now, userId, envelope.baseRevision)
      .first<NativeStateRow>();
    if (row) return json({ state: parseRow(row) });
  }

  const current = await env.DB.prepare(
    "SELECT payload, revision FROM native_workout_state WHERE user_id = ?",
  )
    .bind(userId)
    .first<NativeStateRow>();
  return json(
    {
      code: "STALE_STATE",
      message: "A newer native workout state is already stored.",
      state: parseRow(current),
    },
    409,
  );
}
