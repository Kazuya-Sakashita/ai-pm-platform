import { Suspense } from "react";
import { GitHubCallbackClient } from "./callback-client";

export default async function GitHubCallbackPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  const resolvedSearchParams = await searchParams;
  const firstParam = (key: string) => {
    const value = resolvedSearchParams[key];
    if (typeof value === "string") return value;
    if (Array.isArray(value)) return value[0] ?? "";
    return "";
  };
  const setupAction = firstParam("setup_action");

  return (
    <Suspense fallback={<main className="callback-shell">GitHub接続を確認しています。</main>}>
      <GitHubCallbackClient
        state={firstParam("state")}
        installationId={firstParam("installation_id")}
        setupAction={setupAction === "install" || setupAction === "update" ? setupAction : undefined}
      />
    </Suspense>
  );
}
