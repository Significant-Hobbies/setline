import { createAuth, type SetlineBindings } from "./auth";

async function resolveUserId(
  request: Request,
  env: SetlineBindings,
): Promise<string | null> {
  const session = await createAuth(env, request.url).api.getSession({
    headers: request.headers,
  });
  return session?.user?.id ?? null;
}

type AuthResult =
  { userId: string; response: null } | { userId: null; response: Response };

/**
 * Resolves the authenticated user or returns a 401 response.
 * Shared by private state handlers that gate on browser sessions.
 */
export async function requireUserId(
  request: Request,
  env: SetlineBindings,
): Promise<AuthResult> {
  const userId = await resolveUserId(request, env);
  if (!userId) {
    return {
      userId: null,
      response: Response.json(
        { code: "UNAUTHORIZED", message: "Sign in to continue." },
        { status: 401 },
      ),
    };
  }
  return { userId, response: null };
}
