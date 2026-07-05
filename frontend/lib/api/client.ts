import createClient, { type Middleware } from "openapi-fetch";
import type { paths } from "./schema";

const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:3001/api/v1";
const defaultAuthToken = process.env.NEXT_PUBLIC_AUTH_TOKEN;
const actorId = process.env.NEXT_PUBLIC_ACTOR_ID ?? "local-demo-owner";
const authTokenStorageKey = "ai-pm-auth-token";
const authClearedStorageKey = "ai-pm-auth-cleared";

export const authRequiredEventName = "ai-pm-auth-required";

export type AuthRequiredEventDetail = {
  code?: string;
  message?: string;
  status: number;
  path?: string;
};

const authTerminalErrorCodes = new Set([
  "authentication_required",
  "authentication_not_configured",
  "invalid_token",
  "token_expired",
  "token_not_yet_valid",
  "token_revoked",
  "session_not_found",
  "session_expired",
  "session_revoked",
  "session_version_stale",
  "signing_key_unknown",
  "signing_key_retired",
  "signing_key_not_active",
]);

function browserStorage() {
  if (typeof window === "undefined") return null;
  return window.localStorage;
}

function authIsCleared() {
  return browserStorage()?.getItem(authClearedStorageKey) === "true";
}

function storedAuthToken() {
  if (authIsCleared()) return "";
  return browserStorage()?.getItem(authTokenStorageKey) || defaultAuthToken || "";
}

export function hasBearerAuth() {
  return Boolean(storedAuthToken());
}

export function clearAuthState() {
  const storage = browserStorage();
  storage?.removeItem(authTokenStorageKey);
  storage?.setItem(authClearedStorageKey, "true");
}

export function restoreAuthState() {
  browserStorage()?.removeItem(authClearedStorageKey);
}

export function authHeaders() {
  if (authIsCleared()) return {};

  const authToken = storedAuthToken();
  if (authToken) return { Authorization: `Bearer ${authToken}` };

  return { "X-Actor-Id": actorId };
}

export const apiClient = createClient<paths>({
  baseUrl,
});

const authMiddleware: Middleware = {
  onRequest({ request }) {
    const headers = new Headers(request.headers);
    headers.delete("Authorization");
    headers.delete("X-Actor-Id");

    for (const [key, value] of Object.entries(authHeaders())) {
      headers.set(key, value);
    }

    return new Request(request, { headers });
  },
  async onResponse({ response, schemaPath }) {
    if (response.status !== 401 && response.status !== 503) return undefined;

    const payload = await response.clone().json().catch(() => null);
    const error = payload && typeof payload === "object" && "error" in payload ? payload.error : undefined;
    const code = error && typeof error === "object" && "code" in error ? String(error.code) : undefined;
    const message = error && typeof error === "object" && "message" in error ? String(error.message) : undefined;
    if (!code || !authTerminalErrorCodes.has(code)) return undefined;

    clearAuthState();
    if (typeof window !== "undefined") {
      window.dispatchEvent(
        new CustomEvent<AuthRequiredEventDetail>(authRequiredEventName, {
          detail: {
            code,
            message,
            status: response.status,
            path: schemaPath,
          },
        }),
      );
    }

    return undefined;
  },
};

apiClient.use(authMiddleware);
