/** Cloudflare Worker entry point for Setline. */
import { handleAgentEdge } from "./agent-edge.mjs";
import {
  createAuth,
  isAppleConfigured,
  isGoogleConfigured,
  type SetlineBindings,
} from "./auth";
import { handleMcpRead, handleMcpTokenManagement } from "./mcp";
import {
  consumeNativeHandoff,
  createNativeHandoffCode,
  isAllowedNativeCallback,
  NATIVE_AUTH_CALLBACK,
  saveNativeHandoff,
} from "./native-handoff";
import { handleNativeState } from "./native-state";
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
    const agentResponse = handleAgentEdge(request);
    if (agentResponse) return agentResponse;

    if (url.pathname === "/api/health" && request.method === "GET") {
      return json({
        ok: true,
        auth: {
          googleConfigured: isGoogleConfigured(env),
          appleConfigured: isAppleConfigured(env),
        },
        storage: "d1",
      });
    }

    if (url.pathname === "/api/auth/config" && request.method === "GET") {
      return json({
        googleConfigured: isGoogleConfigured(env),
        appleConfigured: isAppleConfigured(env),
      });
    }

    if (
      url.pathname === "/api/native/auth/google/start" &&
      request.method === "GET"
    ) {
      if (!isGoogleConfigured(env)) {
        return json(
          {
            code: "OAUTH_NOT_CONFIGURED",
            message: "Google sign-in is unavailable.",
          },
          503,
        );
      }
      const callback = url.searchParams.get("callback") ?? NATIVE_AUTH_CALLBACK;
      if (!isAllowedNativeCallback(callback)) {
        return json(
          {
            code: "INVALID_CALLBACK",
            message: "The native callback is not allowed.",
          },
          400,
        );
      }
      const completeURL = new URL(
        "/api/native/auth/google/complete",
        request.url,
      );
      completeURL.searchParams.set("callback", callback);
      const result = await createAuth(env, request.url).api.signInSocial({
        body: {
          provider: "google",
          callbackURL: completeURL.toString(),
          errorCallbackURL: completeURL.toString(),
        },
        headers: request.headers,
      });
      if (!result.url) {
        return json(
          {
            code: "OAUTH_START_FAILED",
            message: "Google sign-in could not start.",
          },
          502,
        );
      }
      return Response.redirect(result.url);
    }

    if (
      url.pathname === "/api/native/auth/google/complete" &&
      request.method === "GET"
    ) {
      const callback = url.searchParams.get("callback") ?? NATIVE_AUTH_CALLBACK;
      if (!isAllowedNativeCallback(callback)) {
        return json(
          {
            code: "INVALID_CALLBACK",
            message: "The native callback is not allowed.",
          },
          400,
        );
      }
      const session = await createAuth(env, request.url).api.getSession({
        headers: request.headers,
      });
      const redirect = new URL(callback);
      if (!session?.session.token) {
        redirect.searchParams.set("error", "google_auth_failed");
        return Response.redirect(redirect.toString());
      }
      const code = createNativeHandoffCode();
      await saveNativeHandoff(env.DB, code, session.session.token);
      redirect.searchParams.set("code", code);
      return Response.redirect(redirect.toString());
    }

    if (
      url.pathname === "/api/native/auth/exchange" &&
      request.method === "POST"
    ) {
      const body = (await request.json().catch(() => null)) as {
        code?: unknown;
      } | null;
      const code = typeof body?.code === "string" ? body.code.trim() : "";
      if (code.length < 32 || code.length > 128) {
        return json(
          {
            code: "INVALID_HANDOFF",
            message: "The sign-in handoff is invalid.",
          },
          400,
        );
      }
      const token = await consumeNativeHandoff(env.DB, code);
      if (!token) {
        return json(
          {
            code: "EXPIRED_HANDOFF",
            message: "The sign-in handoff expired or was already used.",
          },
          401,
        );
      }
      return json({ token });
    }

    if (url.pathname.startsWith("/api/auth/")) {
      if (
        url.pathname.endsWith("/sign-in/social") &&
        request.method === "POST"
      ) {
        const body = (await request
          .clone()
          .json()
          .catch(() => null)) as {
          provider?: unknown;
        } | null;
        if (body?.provider === "google" && !isGoogleConfigured(env)) {
          return json(
            {
              code: "OAUTH_NOT_CONFIGURED",
              message: "Google sign-in is not configured in this environment.",
            },
            503,
          );
        }
        if (body?.provider === "apple" && !isAppleConfigured(env)) {
          return json(
            {
              code: "OAUTH_NOT_CONFIGURED",
              message: "Apple sign-in is not configured in this environment.",
            },
            503,
          );
        }
      }
      const response = await createAuth(env, request.url).handler(request);
      return withApiHeaders(response);
    }

    if (url.pathname.startsWith("/api/app/mcp-tokens")) {
      try {
        return withApiHeaders(await handleMcpTokenManagement(request, env));
      } catch (error) {
        console.error(
          JSON.stringify({
            event: "setline_mcp_token_error",
            method: request.method,
            path: url.pathname,
            message: error instanceof Error ? error.message : "Unknown error",
          }),
        );
        return json(
          {
            code: "TOKEN_UNAVAILABLE",
            message: "Read-token access is unavailable.",
          },
          503,
        );
      }
    }

    if (url.pathname.startsWith("/api/mcp/")) {
      try {
        return withApiHeaders(await handleMcpRead(request, env));
      } catch (error) {
        console.error(
          JSON.stringify({
            event: "setline_mcp_read_error",
            method: request.method,
            path: url.pathname,
            message: error instanceof Error ? error.message : "Unknown error",
          }),
        );
        return json(
          {
            code: "READ_UNAVAILABLE",
            message: "Workout reads are unavailable.",
          },
          503,
        );
      }
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

    if (url.pathname === "/api/native/state") {
      try {
        return withApiHeaders(await handleNativeState(request, env));
      } catch (error) {
        console.error(
          JSON.stringify({
            event: "setline_native_state_error",
            method: request.method,
            message: error instanceof Error ? error.message : "Unknown error",
          }),
        );
        return json(
          {
            code: "STATE_UNAVAILABLE",
            message: "Native sync is temporarily unavailable.",
          },
          503,
        );
      }
    }

    if (url.pathname.startsWith("/api/")) {
      return json({ code: "NOT_FOUND", message: "API route not found." }, 404);
    }

    // Serve static assets (public/ files) for non-API routes.
    if (env.ASSETS) {
      const assetResponse = await env.ASSETS.fetch(request);
      if (assetResponse.status !== 404) return assetResponse;
    }

    // Fallback: return 404 for unknown routes.
    return new Response("Not found", { status: 404 });
  },
};

export default worker;
