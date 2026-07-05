const messageLabels: Record<string, string> = {
  "AI response did not match the expected DM summary schema.": "AI応答が想定されたDM整理形式に一致しませんでした。",
  "AI response did not match the expected minutes schema.": "AI応答が想定された議事録形式に一致しませんでした。",
  "GitHub integration is not connected.": "GitHub連携が未接続です。",
  "GitHub connection state already used.": "GitHub接続リンクは使用済みです。ワークスペースから接続をやり直してください。",
  "GitHub connection state expired.": "GitHub接続リンクの有効期限が切れました。ワークスペースから接続をやり直してください。",
  "GitHub connection state is invalid.": "GitHub接続リンクが無効です。ワークスペースから接続をやり直してください。",
  "GitHub installation could not be verified.": "GitHub Appのインストールを確認できませんでした。",
  "GitHub Issue marker search failed.": "GitHub Issueマーカー検索に失敗しました。",
  "GitHub reconciliation retry is cooling down.": "GitHub照合の再試行待機中です。",
  "GitHub issue URL must match the project repository and issue number.": "GitHub Issue URLはプロジェクトのリポジトリとIssue番号に一致している必要があります。",
  "GitHub issue may have been created. Reconciliation is required.": "GitHub Issueが作成済みの可能性があります。照合が必要です。",
  "GitHub rate limit is active. Retry after the provider limit resets.": "GitHubのレート制限中です。制限解除後に再試行してください。",
  "A retry approver is required for controlled GitHub publish retry.": "GitHub再試行の承認者を入力してください。",
  "A retry reason template is required for controlled GitHub publish retry.": "GitHub再試行の理由テンプレートを選択してください。",
  "Meeting text includes sensitive content that must be reviewed before AI generation.": "会議ログに機密性の高い内容が含まれています。AI生成前にレビューしてください。",
  "Multiple GitHub Issue marker matches were found.": "GitHub Issueマーカー候補が複数見つかりました。",
  "OpenAI API key is not configured.": "OpenAI APIキーが未設定です。",
  "OpenAI request failed before a response was received.": "OpenAIから応答を受け取る前にリクエストが失敗しました。",
  "OpenAI request failed. Retry later or check integration settings.": "OpenAIリクエストに失敗しました。時間を置いて再試行するか、連携設定を確認してください。",
  "OpenAI request was rate limited. Retry after the provider limit resets.": "OpenAIのレート制限に達しました。制限解除後に再試行してください。",
  "OpenAPI validation could not be completed.": "OpenAPI検証を完了できませんでした。",
  "Reconciliation required.": "照合が必要です。",
  "Resolution note is too long for manual GitHub reconciliation.": "GitHub照合の解決メモが長すぎます。",
  "Retry approver is too long for controlled GitHub publish retry.": "GitHub再試行の承認者名が長すぎます。",
  "Retry reason template is invalid for controlled GitHub publish retry.": "GitHub再試行の理由テンプレートが不正です。",
  "Conversation import must be scanned before AI summary generation.": "DMインポートはAI整理前にスキャンしてください。",
  "Conversation import is blocked by safety checks.": "DMインポートは安全チェックでブロックされています。",
  "Conversation import has been anonymized.": "DMインポートは匿名化済みです。",
  "Conversation import anonymization failed.": "DMインポートの匿名化に失敗しました。時間を置いて再試行してください。",
  "Conversation import access is forbidden.": "DMインポートを操作する権限がありません。",
  "Conversation import actor is required.": "DMインポート操作には利用者情報が必要です。",
  "Validation failed": "入力内容の検証に失敗しました。",
};

const statusLabels: Record<string, string> = {
  accepted_risk: "リスク承認済み",
  action_required: "対応が必要",
  approved: "承認済み",
  archived: "アーカイブ済み",
  blocked: "ブロック中",
  cancelled: "キャンセル済み",
  clear: "通過",
  connected: "接続済み",
  draft: "下書き",
  error: "エラー",
  failed: "失敗",
  generated: "生成済み",
  generating: "生成中",
  github_created: "GitHub作成済み",
  degraded: "要確認",
  healthy: "正常",
  in_review: "レビュー中",
  invalid: "検証失敗",
  local_saved: "ローカル保存済み",
  manually_reconciled: "手動照合済み",
  needs_changes: "修正が必要",
  needs_revision: "修正が必要",
  not_connected: "未接続",
  open: "未対応",
  pending: "未対応",
  publish_failed: "GitHub公開失敗",
  published: "公開済み",
  publishing: "公開中",
  ready_for_ai: "AI整理可能",
  redaction_required: "マスキングが必要",
  reconciled: "照合済み",
  reconciliation_required: "GitHub Issueの照合が必要",
  rejected: "却下済み",
  resolved: "解決済み",
  review_required: "レビューが必要",
  retry_approved: "再試行承認済み",
  revoked: "解除済み",
  running: "実行中",
  saved: "保存済み",
  started: "開始済み",
  stale: "再確認が必要",
  summarizing: "整理中",
  summary_draft: "整理ドラフトあり",
  succeeded: "完了",
  unavailable: "利用不可",
  valid: "検証済み",
};

const targetLabels: Record<string, string> = {
  issue_draft: "Issueドラフト",
  conversation_summary_draft: "DM整理ドラフト",
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
