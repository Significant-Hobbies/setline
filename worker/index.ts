/** Cloudflare Worker entry point for Setline. */
import handler from "vinext/server/app-router-entry";
import { createAuth, isGoogleConfigured, type SetlineBindings } from "./auth";
import { handlePrivateState } from "./state";

const SECURITY_HEADERS = {
  "Cache-Control": "no-store",
  "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
  "Referrer-Policy": "strict-origin-when-cross-origin",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
};

function withApiHeaders(response: Response) {
  const headers = new Headers(response.headers);
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    headers.set(name, value);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function json(payload: unknown, status = 200) {
  return withApiHeaders(Response.json(payload, { status }));
}

const worker = {
  async fetch(
    request: Request,
    env: SetlineBindings,
    ctx: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/api/health" && request.method === "GET") {
      return json({
        ok: true,
        auth: { googleConfigured: isGoogleConfigured(env) },
        storage: "d1",
      });
    }

    if (url.pathname === "/api/auth/config" && request.method === "GET") {
      return json({ googleConfigured: isGoogleConfigured(env) });
    }

    if (url.pathname.startsWith("/api/auth/")) {
      if (
        url.pathname.endsWith("/sign-in/social") &&
        request.method === "POST" &&
        !isGoogleConfigured(env)
      ) {
        return json(
          {
            code: "OAUTH_NOT_CONFIGURED",
            message: "Google sign-in is not configured in this environment.",
          },
          503,
        );
      }
      const response = await createAuth(env, request.url).handler(request);
      return withApiHeaders(response);
    }

    if (url.pathname === "/api/app/state") {
      try {
        return withApiHeaders(await handlePrivateState(request, env));
      } catch (error) {
        console.error(
          JSON.stringify({
            event: "setline_state_error",
            method: request.method,
            path: url.pathname,
            message: error instanceof Error ? error.message : "Unknown error",
          }),
        );
        return json(
          {
            code: "STATE_UNAVAILABLE",
            message: "Private workout state is temporarily unavailable.",
          },
          503,
        );
      }
    }

    if (url.pathname.startsWith("/api/")) {
      return json({ code: "NOT_FOUND", message: "API route not found." }, 404);
    }

    return handler.fetch(request, env, ctx);
  },
};

export default worker;
