const messageLabels: Record<string, string> = {
  "AI response did not match the expected minutes schema.": "AI応答が想定された議事録形式に一致しませんでした。",
  "GitHub integration is not connected.": "GitHub連携が未接続です。",
  "GitHub Issue marker search failed.": "GitHub Issueマーカー検索に失敗しました。",
  "GitHub reconciliation retry is cooling down.": "GitHub照合の再試行待機中です。",
  "GitHub issue URL must match the project repository and issue number.": "GitHub Issue URLはプロジェクトのリポジトリとIssue番号に一致している必要があります。",
  "GitHub issue may have been created. Reconciliation is required.": "GitHub Issueが作成済みの可能性があります。照合が必要です。",
  "GitHub rate limit is active. Retry after the provider limit resets.": "GitHubのレート制限中です。制限解除後に再試行してください。",
  "Meeting text includes sensitive content that must be reviewed before AI generation.": "会議ログに機密性の高い内容が含まれています。AI生成前にレビューしてください。",
  "Multiple GitHub Issue marker matches were found.": "GitHub Issueマーカー候補が複数見つかりました。",
  "OpenAI API key is not configured.": "OpenAI APIキーが未設定です。",
  "OpenAI request failed before a response was received.": "OpenAIから応答を受け取る前にリクエストが失敗しました。",
  "OpenAI request failed. Retry later or check integration settings.": "OpenAIリクエストに失敗しました。時間を置いて再試行するか、連携設定を確認してください。",
  "OpenAI request was rate limited. Retry after the provider limit resets.": "OpenAIのレート制限に達しました。制限解除後に再試行してください。",
  "OpenAPI validation could not be completed.": "OpenAPI検証を完了できませんでした。",
  "Reconciliation required.": "照合が必要です。",
  "Validation failed": "入力内容の検証に失敗しました。",
};

const statusLabels: Record<string, string> = {
  action_required: "対応必要",
  approved: "承認済み",
  blocked: "ブロック中",
  clear: "通過",
  draft: "ドラフト",
  failed: "失敗",
  generating: "生成中",
  in_review: "レビュー中",
  invalid: "検証失敗",
  manually_reconciled: "手動照合済み",
  needs_changes: "修正必要",
  open: "未対応",
  pending: "未対応",
  publish_failed: "公開失敗",
  published: "公開済み",
  publishing: "公開中",
  reconciliation_required: "照合必要",
  resolved: "解決済み",
  retry_approved: "再試行承認済み",
  running: "実行中",
  saved: "保存済み",
  succeeded: "成功",
  valid: "検証済み",
};

const targetLabels: Record<string, string> = {
  issue_draft: "Issueドラフト",
  minutes: "議事録",
  openapi_draft: "OpenAPIドラフト",
  requirement: "要件定義",
};

export function displayMessage(message?: string) {
  if (!message) return "";
  return messageLabels[message] ?? message;
}

export function statusLabel(status?: string, fallback = "未生成") {
  if (!status) return fallback;
  return statusLabels[status] ?? status;
}

export function targetLabel(target?: string) {
  if (!target) return "-";
  return targetLabels[target] ?? target;
}

export function yesNoLabel(value: boolean) {
  return value ? "はい" : "いいえ";
}
