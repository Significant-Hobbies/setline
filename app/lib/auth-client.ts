const LOCAL_MODE_KEY = "setline:device-only";
const CACHED_ACCOUNT_KEY = "setline:cached-account";
const STATE_ACCOUNT_KEY = "setline:state-account";

export type Account = {
  id: string;
  name: string;
  email: string;
  image?: string | null;
};

export type AccountState =
  | { status: "authenticated"; account: Account; offline: boolean }
  | { status: "local" }
  | { status: "anonymous" };

type SessionResponse = {
  user?: Account;
} | null;

function readCachedAccount(): Account | null {
  try {
    const raw = localStorage.getItem(CACHED_ACCOUNT_KEY);
    if (!raw) return null;
    const candidate = JSON.parse(raw) as Partial<Account>;
    return typeof candidate.id === "string" &&
      typeof candidate.name === "string" &&
      typeof candidate.email === "string"
      ? {
          id: candidate.id,
          name: candidate.name,
          email: candidate.email,
          image: typeof candidate.image === "string" ? candidate.image : null,
        }
      : null;
  } catch {
    return null;
  }
}

export async function getGoogleConfiguration() {
  try {
    const response = await fetch("/api/auth/config", {
      credentials: "include",
      cache: "no-store",
    });
    if (!response.ok) return false;
    const body = (await response.json()) as { googleConfigured?: boolean };
    return body.googleConfigured === true;
  } catch {
    return false;
  }
}

export async function getAccountState(): Promise<AccountState> {
  if (localStorage.getItem(LOCAL_MODE_KEY) === "true") {
    return { status: "local" };
  }

  try {
    const response = await fetch("/api/auth/get-session", {
      credentials: "include",
      cache: "no-store",
    });
    if (!response.ok) {
      return { status: "anonymous" };
    }
    const session = (await response.json()) as SessionResponse;
    if (!session?.user) {
      localStorage.removeItem(CACHED_ACCOUNT_KEY);
      return { status: "anonymous" };
    }
    localStorage.setItem(CACHED_ACCOUNT_KEY, JSON.stringify(session.user));
    return { status: "authenticated", account: session.user, offline: false };
  } catch {
    const cached = readCachedAccount();
    return cached
      ? { status: "authenticated", account: cached, offline: true }
      : { status: "anonymous" };
  }
}

export function startDeviceOnlyMode() {
  localStorage.setItem(LOCAL_MODE_KEY, "true");
}

export function getStateAccountId() {
  return localStorage.getItem(STATE_ACCOUNT_KEY);
}

export function bindStateToAccount(accountId: string) {
  localStorage.setItem(STATE_ACCOUNT_KEY, accountId);
}

export function clearStateAccountBinding() {
  localStorage.removeItem(STATE_ACCOUNT_KEY);
}

export async function signInWithGoogle() {
  localStorage.removeItem(LOCAL_MODE_KEY);
  const response = await fetch("/api/auth/sign-in/social", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      provider: "google",
      callbackURL: window.location.origin,
      errorCallbackURL: window.location.origin,
    }),
  });
  const body = (await response.json().catch(() => null)) as {
    url?: string;
    message?: string;
  } | null;
  if (!response.ok || !body?.url) {
    throw new Error(body?.message ?? "Google sign-in could not start.");
  }
  window.location.assign(body.url);
}

export async function signOutAccount() {
  const response = await fetch("/api/auth/sign-out", {
    method: "POST",
    credentials: "include",
    headers: { "Content-Type": "application/json" },
    body: "{}",
  });
  if (!response.ok) {
    throw new Error("Sign-out could not be completed.");
  }
  localStorage.removeItem(CACHED_ACCOUNT_KEY);
  localStorage.removeItem(LOCAL_MODE_KEY);
}
