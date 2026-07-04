"use client";

import { AlertTriangle, CheckCircle2, GitBranch, Loader2 } from "lucide-react";
import Link from "next/link";
import { useEffect, useRef, useState } from "react";
import { apiClient } from "@/lib/api/client";
import { displayMessage, statusLabel } from "@/lib/display-labels";
import type { components } from "@/lib/api/schema";

type IntegrationAccount = components["schemas"]["IntegrationAccount"];
type CallbackStatus = "loading" | "success" | "error";
type SetupAction = NonNullable<components["schemas"]["GitHubCallbackRequest"]["setup_action"]>;

type ApiErrorPayload = {
  error?: {
    code?: string;
    message?: string;
  };
};

function errorMessage(error: unknown) {
  const payload = error as ApiErrorPayload;
  return displayMessage(payload.error?.message) || "GitHub接続を完了できませんでした。";
}

function setupActionLabel(action?: SetupAction) {
  if (action === "update") return "更新";
  return "インストール";
}

export function GitHubCallbackClient({
  state,
  installationId,
  setupAction,
}: {
  state: string;
  installationId: string;
  setupAction?: SetupAction;
}) {
  const submittedRef = useRef(false);
  const [status, setStatus] = useState<CallbackStatus>("loading");
  const [message, setMessage] = useState("GitHub接続を確認しています。");
  const [account, setAccount] = useState<IntegrationAccount | null>(null);

  useEffect(() => {
    if (submittedRef.current) return;
    submittedRef.current = true;

    if (!state || !installationId) {
      setStatus("error");
      setMessage("GitHubから必要な接続情報を受け取れませんでした。ワークスペースから接続をやり直してください。");
      return;
    }

    async function completeCallback() {
      const { data, error } = await apiClient.POST("/integrations/github/callback", {
        body: {
          installation_id: installationId,
          state,
          setup_action: setupAction,
        },
      });

      if (error) {
        setStatus("error");
        setMessage(errorMessage(error));
        return;
      }

      setAccount(data.data);
      setStatus("success");
      setMessage("GitHub連携が完了しました。");
    }

    void completeCallback();
  }, [installationId, setupAction, state]);

  const isLoading = status === "loading";
  const isSuccess = status === "success";

  return (
    <main className="callback-shell">
      <section className={`callback-panel ${status}`} aria-live="polite">
        <div className="callback-icon" aria-hidden="true">
          {isLoading ? <Loader2 className="spin" size={28} /> : isSuccess ? <CheckCircle2 size={28} /> : <AlertTriangle size={28} />}
        </div>
        <div className="callback-copy">
          <p className="eyebrow">GitHub連携</p>
          <h1>{isSuccess ? "接続が完了しました" : isLoading ? "接続を確認中" : "接続を完了できませんでした"}</h1>
          <p>{message}</p>
        </div>

        <div className="callback-summary" aria-label="GitHub接続結果">
          <strong>処理</strong>
          <span>{setupActionLabel(setupAction)}</span>
          <strong>状態</strong>
          <span>{isLoading ? "確認中" : isSuccess ? statusLabel(account?.status) : "失敗"}</span>
          <strong>リポジトリ</strong>
          <span>{account ? `${account.repository_owner}/${account.repository_name}` : "-"}</span>
          <strong>アカウント</strong>
          <span>{account?.github_account_login ?? "-"}</span>
        </div>

        <div className="callback-actions">
          <Link className="button primary" href="/">
            <GitBranch size={16} />
            ワークスペースへ戻る
          </Link>
          {!isSuccess && !isLoading ? (
            <Link className="button secondary" href="/#issue-draft">
              <GitBranch size={16} />
              GitHub接続をやり直す
            </Link>
          ) : null}
        </div>
      </section>
    </main>
  );
}
