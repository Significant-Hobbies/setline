import { betterAuth } from "better-auth";
import { drizzleAdapter } from "better-auth/adapters/drizzle";
import { bearer } from "better-auth/plugins";
import { drizzle } from "drizzle-orm/d1";
import { account, session, user, verification } from "./schema";

export type SetlineBindings = CloudflareBindings & {
  BETTER_AUTH_SECRET?: string;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  APPLE_APP_BUNDLE_IDENTIFIER?: string;
};

const PRODUCTION_ORIGIN = "https://setline.significanthobbies.com";
const LOCAL_ORIGINS = [
  "http://localhost:3000",
  "http://localhost:3001",
  "http://127.0.0.1:3000",
  "http://127.0.0.1:3001",
];

function isLocalOrigin(origin: string) {
  const hostname = new URL(origin).hostname;
  return hostname === "localhost" || hostname === "127.0.0.1";
}

export function isGoogleConfigured(env: SetlineBindings) {
  return Boolean(
    env.BETTER_AUTH_SECRET?.trim() &&
    env.GOOGLE_CLIENT_ID?.trim() &&
    env.GOOGLE_CLIENT_SECRET?.trim(),
  );
}

export function isAppleConfigured(env: SetlineBindings) {
  return Boolean(env.APPLE_APP_BUNDLE_IDENTIFIER?.trim());
}

export function createAuth(env: SetlineBindings, requestUrl: string) {
  const requestOrigin = new URL(requestUrl).origin;
  const baseURL = isLocalOrigin(requestOrigin)
    ? requestOrigin
    : PRODUCTION_ORIGIN;
  const secret =
    env.BETTER_AUTH_SECRET?.trim() ??
    (isLocalOrigin(requestOrigin)
      ? "setline-local-development-secret-never-use-in-production"
      : undefined);
  const appleBundleIdentifier = env.APPLE_APP_BUNDLE_IDENTIFIER?.trim() ?? "";

  return betterAuth({
    database: drizzleAdapter(drizzle(env.DB), {
      provider: "sqlite",
      schema: { user, session, account, verification },
    }),
    baseURL,
    secret,
    socialProviders: {
      google: {
        clientId: env.GOOGLE_CLIENT_ID?.trim() ?? "",
        clientSecret: env.GOOGLE_CLIENT_SECRET?.trim() ?? "",
        scope: ["openid", "email", "profile"],
        prompt: "select_account",
      },
      ...(isAppleConfigured(env)
        ? {
            apple: {
              clientId: appleBundleIdentifier,
              clientSecret: "",
              appBundleIdentifier: appleBundleIdentifier,
            },
          }
        : {}),
    },
    account: {
      accountLinking: {
        enabled: true,
        disableImplicitLinking: true,
        trustedProviders: ["google", "apple"],
        allowDifferentEmails: true,
      },
    },
    user: {
      deleteUser: {
        enabled: true,
      },
    },
    plugins: [bearer()],
    trustedOrigins: [
      ...new Set([
        baseURL,
        ...LOCAL_ORIGINS,
        "https://appleid.apple.com",
        "setline://auth",
      ]),
    ],
    rateLimit: {
      enabled: false,
    },
  });
}
