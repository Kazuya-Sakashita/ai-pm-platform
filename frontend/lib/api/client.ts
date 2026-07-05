import createClient from "openapi-fetch";
import type { paths } from "./schema";

const baseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:3001/api/v1";
const actorId = process.env.NEXT_PUBLIC_ACTOR_ID ?? "local-demo-owner";

export function actorHeader() {
  return { "X-Actor-Id": actorId };
}

export const apiClient = createClient<paths>({
  baseUrl,
  headers: {
    "X-Actor-Id": actorId,
  },
});
