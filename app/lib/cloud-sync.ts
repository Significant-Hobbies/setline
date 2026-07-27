import { parseStoredState, type StoredState } from "./workout-state";

type CloudStateResponse = {
  state?: unknown;
  message?: string;
};

export type CloudReadResult =
  | { status: "ok"; state: StoredState | null }
  | { status: "unauthorized" }
  | { status: "unavailable"; message: string };

export type CloudWriteResult =
  | { status: "ok"; state: StoredState }
  | { status: "conflict"; state: StoredState }
  | { status: "unauthorized" }
  | { status: "unavailable"; message: string };

export async function readCloudState(): Promise<CloudReadResult> {
  try {
    const response = await fetch("/api/app/state", {
      credentials: "include",
      cache: "no-store",
    });
    if (response.status === 401) return { status: "unauthorized" };
    const body = (await response.json().catch(() => null)) as CloudStateResponse | null;
    if (!response.ok) {
      return {
        status: "unavailable",
        message: body?.message ?? "Cloud state is temporarily unavailable.",
      };
    }
    if (body?.state === null || body?.state === undefined) {
      return { status: "ok", state: null };
    }
    const state = parseStoredState(body.state);
    return state
      ? { status: "ok", state }
      : { status: "unavailable", message: "Cloud state has an unsupported format." };
  } catch {
    return { status: "unavailable", message: "Cloud state is unreachable." };
  }
}

export async function writeCloudState(state: StoredState): Promise<CloudWriteResult> {
  try {
    const response = await fetch("/api/app/state", {
      method: "PUT",
      credentials: "include",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(state),
    });
    if (response.status === 401) return { status: "unauthorized" };
    const body = (await response.json().catch(() => null)) as CloudStateResponse | null;
    const returnedState = parseStoredState(body?.state);
    if (response.status === 409 && returnedState) {
      return { status: "conflict", state: returnedState };
    }
    if (!response.ok || !returnedState) {
      return {
        status: "unavailable",
        message: body?.message ?? "Cloud state could not be saved.",
      };
    }
    return { status: "ok", state: returnedState };
  } catch {
    return { status: "unavailable", message: "Cloud state is unreachable." };
  }
}
