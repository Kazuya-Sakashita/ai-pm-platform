"use client";

import {
  Activity,
  AlertTriangle,
  CheckCircle2,
  CircleDot,
  ClipboardList,
  Database,
  FileCheck2,
  FileCode2,
  GitBranch,
  ListChecks,
  Loader2,
  MessageSquareText,
  Play,
  Plus,
  RefreshCw,
  Save,
  Send,
  ShieldCheck,
  Trash2,
  UserMinus,
  UserPlus,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  apiClient,
  authRequiredEventName,
  clearAuthState,
  hasBearerAuth,
  restoreAuthState,
  type AuthRequiredEventDetail,
} from "@/lib/api/client";
import { displayMessage, statusLabel, targetLabel, yesNoLabel } from "@/lib/display-labels";
import type { components } from "@/lib/api/schema";

type AuthSession = components["schemas"]["AuthSession"];
type AuthSessionListMeta = components["schemas"]["AuthSessionListMeta"];
type Project = components["schemas"]["Project"];
type Meeting = components["schemas"]["Meeting"];
type Minutes = components["schemas"]["Minutes"];
type Requirement = components["schemas"]["Requirement"];
type RequirementHistoryItem = components["schemas"]["RequirementHistoryItem"];
type RequirementHistoryChange = components["schemas"]["RequirementHistoryChange"];
type RequirementHistoryValue = components["schemas"]["RequirementHistoryValue"];
type IssueDraft = components["schemas"]["IssueDraft"];
type OpenApiDraft = components["schemas"]["OpenApiDraft"];
type OpenApiValidationResult = components["schemas"]["OpenApiValidationResponse"]["data"];
type Job = components["schemas"]["Job"];
type QueueHealth = components["schemas"]["QueueHealth"];
type FailedJobSample = components["schemas"]["FailedJobSample"];
type FailedJobReleaseGate = components["schemas"]["FailedJobReleaseGate"];
type FailedJobReleaseGateCheck = components["schemas"]["FailedJobReleaseGateCheck"];
type FailedJobDiscardApproval = components["schemas"]["FailedJobDiscardApproval"];
type FailedJobOperationReasonTemplate = components["schemas"]["FailedJobOperationReasonTemplate"];
type FailedJobRetryReasonTemplate = components["schemas"]["FailedJobRetryReasonTemplate"];
type FailedJobDiscardReasonTemplate = components["schemas"]["FailedJobDiscardReasonTemplate"];
type FailedJobProductJobMappingSource = components["schemas"]["FailedJobProductJobMappingSource"];
type FailedJobOperationHistoryItem = components["schemas"]["FailedJobOperationHistoryItem"];
type Review = components["schemas"]["Review"];
type IntegrationAccount = components["schemas"]["IntegrationAccount"];
type MeetingSourceType = components["schemas"]["MeetingSourceType"];
type ConversationImport = components["schemas"]["ConversationImport"];
type ConversationSummaryDraft = components["schemas"]["ConversationSummaryDraft"];
type ConversationDecision = components["schemas"]["ConversationDecision"];
type ConversationActionItem = components["schemas"]["ConversationActionItem"];
type ConversationIssueCandidate = components["schemas"]["ConversationIssueCandidate"];
type ConversationRequirementCandidate = components["schemas"]["ConversationRequirementCandidate"];
type ConversationRisk = components["schemas"]["ConversationRisk"];
type ConversationParticipant = components["schemas"]["ConversationParticipant"];
type ConversationSafetyFlag = components["schemas"]["ConversationSafetyFlag"];
type ConversationRedactionSuggestion = components["schemas"]["ConversationRedactionSuggestion"];
type ProjectMembership = components["schemas"]["ProjectMembership"];
type ProjectMembershipRole = components["schemas"]["ProjectMembershipRole"];
type GitHubReconciliationAction = components["schemas"]["ResolveGitHubReconciliationRequest"]["resolution_action"];
type GitHubReconciliationMatch = components["schemas"]["GitHubReconciliationMatch"];
type GitHubReconciliationHistoryItem = NonNullable<components["schemas"]["IssueDraft"]["github_reconciliation_history"]>[number];
type RetryReasonTemplate = NonNullable<components["schemas"]["ResolveGitHubReconciliationRequest"]["retry_reason_template"]>;
type GitHubReconciliationSearchSummary = {
  search_total_count?: number;
  search_incomplete_results?: boolean;
  search_result_limit?: number;
  search_has_more_results?: boolean;
};

type ConversationSummaryDraftEditForm = {
  summary: string;
  decisions: string;
  openQuestions: string;
  actionItems: string;
  issueCandidates: string;
  requirementCandidates: string;
  risks: string;
};

type RequirementApprovalBlocker = {
  key: string;
  title: string;
  status: string;
  detail: string;
};

type RequirementFocusTone = "success" | "warning" | "danger" | "review" | "neutral";

type RequirementDecisionSummaryItem = {
  key: string;
  title: string;
  value: string;
  detail: string;
  action: string;
  tone: RequirementFocusTone;
};

type RequirementAttentionItem = {
  key: string;
  label: string;
  body: string;
  meta: string;
  tone: RequirementFocusTone;
};

type ApplyRequirementOptions = {
  resetDownstream?: boolean;
  staleDownstream?: boolean;
};

type ApiErrorPayload = {
  error?: {
    code?: string;
    message?: string;
    details?: Record<string, unknown>;
  };
};

const defaultLog = `alice: Decision: Discord-firstで議事録MVPを切る。
bob: Open question: レビュー依頼の担当者は誰にする？
alice: Action: 会議ワークスペースから議事録生成を接続する。`;

const defaultDmText = `依頼者: 決定: MVPではDiscord DMを手動貼り付けで整理する。
PM: 未決: 相手方同意とマスキング確認をどこで記録する？
依頼者: 対応: 同意確認後にIssue候補を作る。`;

const conversationConsentStatementVersion = "discord-dm-manual-import-v1";
const defaultRequirementApprovalNote = "要件定義レビューの指摘を反映し、下流工程へ進めます。";

const retryReasonTemplates: { value: RetryReasonTemplate; label: string }[] = [
  { value: "github_issue_absence_confirmed", label: "GitHub上でIssue未作成を確認" },
  { value: "github_search_complete_no_match", label: "GitHub Search完了後も該当Issueなし" },
  { value: "provider_transient_failure_confirmed", label: "外部APIの一時失敗を確認" },
];

const failedJobOperationReasonLabels: Record<FailedJobOperationReasonTemplate, string> = {
  transient_failure_recovered: "一時障害が解消済み",
  operator_confirmed_safe_retry: "副作用リスクを確認済み",
  manually_resolved: "手動対応済み",
  unsafe_to_retry: "再実行せず破棄",
};

const defaultFailedJobRetryReasonTemplates: FailedJobRetryReasonTemplate[] = ["operator_confirmed_safe_retry", "transient_failure_recovered"];
const defaultFailedJobDiscardReasonTemplates: FailedJobDiscardReasonTemplate[] = ["manually_resolved", "unsafe_to_retry"];

const failedJobOperationActionLabels: Record<FailedJobOperationHistoryItem["action"], string> = {
  retry: "再実行",
  discard: "破棄",
  boundary_rejected: "境界拒否",
};

const failedJobMappingSourceLabels: Record<FailedJobProductJobMappingSource, string> = {
  explicit: "明示マッピング",
  arguments: "引数復元",
};

const failedJobDiscardApprovalStatusLabels: Record<FailedJobDiscardApproval["status"], string> = {
  pending: "承認待ち",
  approved: "承認済み",
  rejected: "却下",
  expired: "期限切れ",
  consumed: "使用済み",
};

const failedJobReleaseGateStatusLabels: Record<FailedJobReleaseGate["status"], string> = {
  pass: "通過",
  warning: "要判断",
  blocked: "停止",
  not_evaluated: "未評価",
};

const failedJobReleaseGateCheckStatusLabels: Record<FailedJobReleaseGateCheck["status"], string> = {
  pass: "通過",
  warning: "警告",
  blocked: "停止",
  not_measured: "未計測",
};

const failedJobReleaseGateSeverityLabels: Record<FailedJobReleaseGateCheck["severity"], string> = {
  info: "情報",
  warning: "警告",
  critical: "重大",
};

const projectMembershipRoles: ProjectMembershipRole[] = ["owner", "admin", "editor", "reviewer", "viewer", "auditor"];

function today() {
  return new Date().toISOString().slice(0, 10);
}

function linesToText(items: string[]) {
  return items.join("\n");
}

function compactLines(value: string) {
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
}

function conversationParticipantsFromText(value: string): ConversationParticipant[] {
  return compactLines(value.replaceAll(",", "\n")).map((displayName) => ({
    display_name: displayName,
    role: "unknown",
  }));
}

function editableConversationSummaryStatus(status?: ConversationSummaryDraft["status"]) {
  return status === "draft" || status === "needs_revision";
}

function blockingReviewStatus(status?: Review["status"]) {
  return status === "open" || status === "action_required";
}

function acceptedRiskExpiresAt(review: Review) {
  const risk = review.accepted_risk as { expires_at?: string } | undefined;
  return risk?.expires_at;
}

function acceptedRiskExpired(review: Review) {
  if (review.status !== "accepted_risk") return false;
  const expiresAt = acceptedRiskExpiresAt(review);
  if (!expiresAt) return true;
  const timestamp = Date.parse(expiresAt);
  return Number.isNaN(timestamp) || timestamp <= Date.now();
}

function conversationDraftEditFormFromDraft(draft: ConversationSummaryDraft | null): ConversationSummaryDraftEditForm {
  return {
    summary: draft?.summary ?? "",
    decisions: linesToText(draft?.decisions.map((decision) => decision.text) ?? []),
    openQuestions: linesToText(draft?.open_questions ?? []),
    actionItems: linesToText(draft?.action_items.map((action) => action.text) ?? []),
    issueCandidates: linesToText(
      draft?.issue_candidates.map((candidate) => [candidate.title, candidate.priority, candidate.body].filter(Boolean).join(" | ")) ?? []
    ),
    requirementCandidates: linesToText(
      draft?.requirement_candidates.map((candidate) =>
        [candidate.title, candidate.requirement, candidate.acceptance_criteria.join("、")].filter(Boolean).join(" | ")
      ) ?? []
    ),
    risks: linesToText(draft?.risks.map((risk) => risk.text) ?? []),
  };
}

function conversationDecisionsFromText(value: string, existing: ConversationDecision[]): ConversationDecision[] {
  return compactLines(value).map((text, index) => ({
    ...existing[index],
    text,
    confidence: existing[index]?.confidence ?? 0.5,
  }));
}

function conversationActionItemsFromText(value: string, existing: ConversationActionItem[]): ConversationActionItem[] {
  return compactLines(value).map((text, index) => ({
    ...existing[index],
    text,
    status: existing[index]?.status ?? "open",
    confidence: existing[index]?.confidence ?? 0.5,
  }));
}

function conversationIssueCandidatesFromText(value: string, existing: ConversationIssueCandidate[]): ConversationIssueCandidate[] {
  return compactLines(value).map((line, index) => {
    const [titlePart, priorityPart, ...bodyParts] = line.split("|").map((part) => part.trim());
    const priority = ["P0", "P1", "P2", "P3"].includes(priorityPart) ? (priorityPart as ConversationIssueCandidate["priority"]) : existing[index]?.priority ?? "P2";
    return {
      ...existing[index],
      title: titlePart || existing[index]?.title || "未整理のIssue候補",
      priority,
      body: bodyParts.join(" | ") || existing[index]?.body || titlePart || "詳細未記入",
      labels: existing[index]?.labels ?? [],
      confidence: existing[index]?.confidence ?? 0.5,
    };
  });
}

function conversationRequirementCandidatesFromText(value: string, existing: ConversationRequirementCandidate[]): ConversationRequirementCandidate[] {
  return compactLines(value).map((line, index) => {
    const [titlePart, requirementPart, criteriaPart] = line.split("|").map((part) => part.trim());
    return {
      ...existing[index],
      title: titlePart || existing[index]?.title || "未整理の要件候補",
      requirement: requirementPart || existing[index]?.requirement || titlePart || "要件未記入",
      acceptance_criteria: compactLines((criteriaPart || "").replaceAll("、", "\n").replaceAll(",", "\n")),
      confidence: existing[index]?.confidence ?? 0.5,
    };
  });
}

function conversationRisksFromText(value: string, existing: ConversationRisk[]): ConversationRisk[] {
  return compactLines(value).map((text, index) => ({
    ...existing[index],
    text,
    severity: existing[index]?.severity ?? "medium",
    confidence: existing[index]?.confidence ?? 0.5,
  }));
}

function summaryConfidence(value?: number) {
  if (typeof value !== "number") return "-";
  return `${Math.round(value * 100)}%`;
}

function safetyFlagTypeLabel(type: ConversationSafetyFlag["type"]) {
  const labels: Record<ConversationSafetyFlag["type"], string> = {
    consent_missing: "同意未確認",
    credential: "認証情報",
    financial: "金融情報",
    legal: "法務情報",
    personal_data: "個人情報",
    secret: "秘密情報",
    unknown: "要確認",
  };

  return labels[type];
}

function errorMessage(error: unknown) {
  const payload = error as ApiErrorPayload;
  return displayMessage(payload.error?.message) || "APIリクエストに失敗しました。";
}

function errorJobId(error: unknown) {
  const payload = error as ApiErrorPayload;
  const value = payload.error?.details?.job_id;
  return typeof value === "string" ? value : undefined;
}

type LegacyFailedJobSample = Omit<FailedJobSample, "operations"> & {
  operations: Omit<FailedJobSample["operations"], "retry_reason_templates" | "discard_reason_templates"> &
    Partial<Pick<FailedJobSample["operations"], "retry_reason_templates" | "discard_reason_templates">>;
};

type LegacyQueueHealth = Omit<
  QueueHealth,
  "failed_job_samples" | "failed_job_operation_metrics" | "failed_job_operation_history" | "failed_job_release_gate"
> & {
  failed_job_samples?: LegacyFailedJobSample[];
  failed_job_operation_metrics?: QueueHealth["failed_job_operation_metrics"];
  failed_job_operation_history?: QueueHealth["failed_job_operation_history"];
  failed_job_release_gate?: QueueHealth["failed_job_release_gate"];
};

function defaultFailedJobOperationMetrics(): QueueHealth["failed_job_operation_metrics"] {
  return {
    recent_window_hours: 24,
    retry_count: 0,
    discard_count: 0,
    rejected_count: 0,
  };
}

function defaultFailedJobReleaseGate(): QueueHealth["failed_job_release_gate"] {
  return {
    status: "not_evaluated",
    notification_required: false,
    notification_channel: "operations",
    notification_policy: {
      channel: "operations",
      required_for: ["release_gate_warning", "release_gate_blocked", "failed_job_operation_executed", "notification_failed"],
      payload_fields: [
        "project_id",
        "failed_job_id",
        "job_id",
        "queue_name",
        "class_name",
        "action",
        "reason_template",
        "operator_actor_id",
        "audit_log_action",
        "discard_approval_id",
        "discard_approval_requested_by_actor_id",
        "discard_approval_approved_by_actor_id",
        "discard_approval_expires_at",
        "release_gate_status",
      ],
      prohibited_fields: ["raw_exception", "backtrace", "serialized_arguments", "token", "database_url", "dm_body", "ai_prompt"],
      fallback: "通知失敗時はAuditLogまたはrelease evidenceへsafe metadataのみを保存し、release ownerが手動確認します。",
    },
    approval_policy: {
      retry: {
        operation: "retry",
        approval_required: false,
        second_approval_required: false,
        required_role: "admin以上",
        next_action: "理由テンプレートと副作用確認をAuditLogに残します。",
      },
      discard: {
        operation: "discard",
        approval_required: true,
        second_approval_required: true,
        required_role: "ownerまたはrelease owner",
        next_action: "本番discardは二人承認またはrelease owner承認を証跡化します。",
      },
      production: {
        operation: "production_failed_job_operation",
        approval_required: true,
        second_approval_required: true,
        required_role: "incident commanderまたはrelease owner",
        next_action: "productionは観測のみを既定とし、実操作時は承認、Project特定、AuditLog確認を必須にします。",
      },
    },
    checks: [],
  };
}

function normalizeFailedJobSample(job: LegacyFailedJobSample): FailedJobSample {
  const retryReasonTemplates =
    job.operations.retry_reason_templates && job.operations.retry_reason_templates.length > 0
      ? job.operations.retry_reason_templates
      : defaultFailedJobRetryReasonTemplates;
  const discardReasonTemplates =
    job.operations.discard_reason_templates && job.operations.discard_reason_templates.length > 0
      ? job.operations.discard_reason_templates
      : defaultFailedJobDiscardReasonTemplates;
  const reasonTemplates: FailedJobOperationReasonTemplate[] = [...retryReasonTemplates, ...discardReasonTemplates];

  return {
    ...job,
    operations: {
      ...job.operations,
      retry_reason_templates: retryReasonTemplates,
      discard_reason_templates: discardReasonTemplates,
      reason_templates: job.operations.reason_templates ?? reasonTemplates,
    },
  };
}

function normalizeQueueHealth(queueHealth: QueueHealth): QueueHealth {
  const legacyQueueHealth = queueHealth as LegacyQueueHealth;

  return {
    ...queueHealth,
    failed_job_samples: (legacyQueueHealth.failed_job_samples ?? []).map(normalizeFailedJobSample),
    failed_job_operation_metrics: legacyQueueHealth.failed_job_operation_metrics ?? defaultFailedJobOperationMetrics(),
    failed_job_operation_history: legacyQueueHealth.failed_job_operation_history ?? [],
    failed_job_release_gate: legacyQueueHealth.failed_job_release_gate ?? defaultFailedJobReleaseGate(),
  };
}

const authRecoveryMessages: Record<string, string> = {
  authentication_required: "ログインが必要です。再ログインしてください。",
  authentication_not_configured: "認証設定が未完了です。管理者に確認してください。",
  invalid_token: "ログイン情報が無効です。再ログインしてください。",
  token_expired: "ログインの有効期限が切れました。再ログインしてください。",
  token_not_yet_valid: "ログイン情報がまだ有効ではありません。時間を確認して再ログインしてください。",
  token_revoked: "ログイン情報は失効しています。再ログインしてください。",
  session_not_found: "ログインセッションを確認できませんでした。再ログインしてください。",
  session_expired: "ログインセッションの有効期限が切れました。再ログインしてください。",
  session_revoked: "ログインセッションは失効しています。再ログインしてください。",
  session_version_stale: "他の端末または管理者操作によりログイン状態が更新されました。再ログインしてください。",
  signing_key_unknown: "ログイン情報を確認できませんでした。再ログインしてください。",
  signing_key_retired: "ログイン情報の署名鍵が更新されています。再ログインしてください。",
  signing_key_not_active: "ログイン情報を確認できませんでした。再ログインしてください。",
};

function authRecoveryMessage(detail?: Partial<AuthRequiredEventDetail>) {
  if (detail?.code && authRecoveryMessages[detail.code]) return authRecoveryMessages[detail.code];
  return displayMessage(detail?.message) || "ログイン状態を確認できませんでした。再ログインしてください。";
}

function githubIssueUrlValidationError(value: string, issueNumber: number, githubRepo?: string) {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return "GitHub Issue URLはhttpsのGitHub Issue URLで入力してください。";
    if (url.hostname !== "github.com") return "GitHub Issue URLはgithub.comのIssue URLを入力してください。";

    const [owner, repository, resource, number] = url.pathname.replace(/^\/+/, "").split("/");
    if (resource !== "issues" || number !== String(issueNumber)) {
      return "GitHub Issue URLはIssue番号と一致している必要があります。";
    }

    if (githubRepo) {
      const [expectedOwner, expectedRepository] = githubRepo.split("/");
      const sameRepository =
        owner?.toLowerCase() === expectedOwner?.toLowerCase() && repository?.toLowerCase() === expectedRepository?.toLowerCase();
      if (!sameRepository) return "GitHub Issue URLはプロジェクトのリポジトリとIssue番号に一致している必要があります。";
    }

    return "";
  } catch {
    return "GitHub Issue URLは有効なURLで入力してください。";
  }
}

function reconciliationHistorySummary(entry: GitHubReconciliationHistoryItem) {
  if (entry.retry_approver || entry.retry_reason_template_label || entry.retry_reason_template) {
    return `承認者 ${entry.retry_approver ?? "-"} / 理由 ${entry.retry_reason_template_label ?? entry.retry_reason_template ?? "-"}`;
  }

  if (entry.safe_error_detail) return displayMessage(entry.safe_error_detail);
  if (entry.github_issue_number) return `GitHub Issue #${entry.github_issue_number} を記録`;
  return "照合履歴を記録済み";
}

function requirementFieldLabel(field: string) {
  const labels: Record<string, string> = {
    background: "背景",
    goal: "目的",
    user_stories: "ユーザーストーリー",
    functional_requirements: "機能要件",
    non_functional_requirements: "非機能要件",
    acceptance_criteria: "受け入れ条件",
    out_of_scope: "スコープ外",
    open_questions: "未解決事項",
    risks: "リスク",
  };

  return labels[field] ?? field;
}

function requirementHistoryValueLabel(value: RequirementHistoryValue) {
  if (value.redacted) return value.preview ?? "機密情報を含むため非表示";
  if (value.preview) return value.preview;
  if (value.item_count > 0) return `${value.item_count}件`;
  return "空";
}

function requirementHistoryChangeLabel(change: RequirementHistoryChange) {
  return `${requirementFieldLabel(change.field)}: ${requirementHistoryValueLabel(change.before)} から ${requirementHistoryValueLabel(change.after)}`;
}

function trimSummaryText(value?: string) {
  const trimmed = value?.trim();
  if (!trimmed) return "";
  return trimmed.length > 90 ? `${trimmed.slice(0, 90)}...` : trimmed;
}

function requirementHistoryMeta(item: RequirementHistoryItem) {
  if (item.source_type === "review" || item.source_type === "review_event") {
    const statusTransition = item.from_status ? `${statusLabel(item.from_status)} から ${statusLabel(item.to_status ?? item.review_status)}` : statusLabel(item.to_status ?? item.review_status);
    const actor = item.actor_id ? `担当 ${item.actor_id}` : null;
    const reviewer = item.reviewer_role ?? "-";
    return [statusTransition, reviewer, actor].filter(Boolean).join(" / ");
  }

  if (item.approval_reset) return "承認差し戻し";
  if (item.changed_fields?.length) return `変更 ${item.changed_fields.map(requirementFieldLabel).join("、")}`;
  if (item.actor_id) return `担当 ${item.actor_id}`;
  return item.action ?? "-";
}

function requirementHistoryTone(item: RequirementHistoryItem) {
  if (item.event_type === "updated" && item.approval_reset) return "warning";
  if (item.event_type === "review_requested" || item.event_type === "review_reopened") return "review";
  if (item.event_type === "review_action_required" || item.event_type === "review_risk_accepted") return "warning";
  if (item.event_type === "generated" || item.event_type === "approved" || item.event_type === "review_resolved") return "success";
  return statusTone(item.review_status ?? item.event_type);
}

function formatDateTime(value?: string) {
  if (!value) return "-";
  return new Intl.DateTimeFormat("ja-JP", {
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  }).format(new Date(value));
}

function isFutureDateTime(value?: string) {
  return Boolean(value && Date.parse(value) > Date.now());
}

function statusTone(status?: string) {
  if (
    status === "active" ||
    status === "approved" ||
    status === "connected" ||
    status === "succeeded" ||
    status === "valid" ||
    status === "published" ||
    status === "reconciled" ||
    status === "retry_approved" ||
    status === "resolved" ||
    status === "local_saved" ||
    status === "ready_for_ai" ||
    status === "healthy" ||
    status === "pass"
  ) {
    return "success";
  }
  if (
    status === "failed" ||
    status === "needs_changes" ||
    status === "needs_revision" ||
    status === "invalid" ||
    status === "publish_failed" ||
    status === "unavailable" ||
    status === "rejected" ||
    status === "blocked" ||
    status === "block" ||
    status === "action_required"
  )
    return "danger";
  if (status === "degraded" || status === "stale" || status === "accepted_risk" || status === "warning") return "warning";
  if (status === "error" || status === "revoked") return "danger";
  if (
    status === "in_review" ||
    status === "open" ||
    status === "running" ||
    status === "generating" ||
    status === "summarizing" ||
    status === "summary_draft" ||
    status === "publishing" ||
    status === "started" ||
    status === "github_created" ||
    status === "reconciliation_required"
  ) {
    return "review";
  }
  return "neutral";
}

function githubIssueStateLabel(state?: string) {
  if (state === "open") return "未解決";
  if (state === "closed") return "クローズ";
  return state || "-";
}

export default function MeetingWorkspace() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedProjectId, setSelectedProjectId] = useState("");
  const [meetings, setMeetings] = useState<Meeting[]>([]);
  const [selectedMeeting, setSelectedMeeting] = useState<Meeting | null>(null);
  const [minutes, setMinutes] = useState<Minutes | null>(null);
  const [requirement, setRequirement] = useState<Requirement | null>(null);
  const [issueDraft, setIssueDraft] = useState<IssueDraft | null>(null);
  const [openApiDraft, setOpenApiDraft] = useState<OpenApiDraft | null>(null);
  const [openApiValidation, setOpenApiValidation] = useState<OpenApiValidationResult | null>(null);
  const [lastJob, setLastJob] = useState<Job | null>(null);
  const [queueHealth, setQueueHealth] = useState<QueueHealth | null>(null);
  const [queueHealthLoading, setQueueHealthLoading] = useState(false);
  const [failedJobOperationId, setFailedJobOperationId] = useState<number | null>(null);
  const [failedJobRetryReasonTemplates, setFailedJobRetryReasonTemplates] = useState<Record<number, FailedJobRetryReasonTemplate>>({});
  const [failedJobDiscardReasonTemplates, setFailedJobDiscardReasonTemplates] = useState<Record<number, FailedJobDiscardReasonTemplate>>({});
  const [failedJobDiscardConfirmations, setFailedJobDiscardConfirmations] = useState<Record<number, boolean>>({});
  const [failedJobApprovalNotes, setFailedJobApprovalNotes] = useState<Record<string, string>>({});
  const [failedJobRejectionReasons, setFailedJobRejectionReasons] = useState<Record<string, string>>({});
  const [lastReview, setLastReview] = useState<Review | null>(null);
  const [requirementReviews, setRequirementReviews] = useState<Review[]>([]);
  const [requirementHistory, setRequirementHistory] = useState<RequirementHistoryItem[]>([]);
  const [openApiReview, setOpenApiReview] = useState<Review | null>(null);
  const [integrationAccounts, setIntegrationAccounts] = useState<IntegrationAccount[]>([]);
  const [projectMemberships, setProjectMemberships] = useState<ProjectMembership[]>([]);
  const [authSessions, setAuthSessions] = useState<AuthSession[]>([]);
  const [authSessionMeta, setAuthSessionMeta] = useState<AuthSessionListMeta | null>(null);
  const [statusMessage, setStatusMessage] = useState("API接続待機中");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [clientReady, setClientReady] = useState(false);
  const [authLocked, setAuthLocked] = useState(false);
  const [authLockCode, setAuthLockCode] = useState("");
  const [authLockMessage, setAuthLockMessage] = useState("");
  const [githubInstallationUrl, setGithubInstallationUrl] = useState("");
  const authLockHeadingRef = useRef<HTMLHeadingElement>(null);
  const authLockedRef = useRef(false);

  const [projectName, setProjectName] = useState("AI議事録プラットフォーム");
  const [projectRepo, setProjectRepo] = useState("Kazuya-Sakashita/ai-pm-platform");
  const [newMemberActorId, setNewMemberActorId] = useState("");
  const [newMemberRole, setNewMemberRole] = useState<ProjectMembershipRole>("viewer");
  const [meetingTitle, setMeetingTitle] = useState("Discordプロダクト同期");
  const [meetingDate, setMeetingDate] = useState(today());
  const [sourceType, setSourceType] = useState<MeetingSourceType>("discord_log");
  const [participants, setParticipants] = useState("Kazuya, プロダクト, エンジニアリング");
  const [rawText, setRawText] = useState(defaultLog);

  const [conversationImports, setConversationImports] = useState<ConversationImport[]>([]);
  const [selectedConversationImport, setSelectedConversationImport] = useState<ConversationImport | null>(null);
  const [conversationSummaryDraft, setConversationSummaryDraft] = useState<ConversationSummaryDraft | null>(null);
  const [conversationSummaryReview, setConversationSummaryReview] = useState<Review | null>(null);
  const [conversationSummaryDraftEdit, setConversationSummaryDraftEdit] = useState<ConversationSummaryDraftEditForm>(() =>
    conversationDraftEditFormFromDraft(null)
  );
  const [conversationSafetyFlags, setConversationSafetyFlags] = useState<ConversationSafetyFlag[]>([]);
  const [conversationRedactionSuggestions, setConversationRedactionSuggestions] = useState<ConversationRedactionSuggestion[]>([]);
  const [conversationTitle, setConversationTitle] = useState("Discord DM仕様相談");
  const [conversationParticipants, setConversationParticipants] = useState("依頼者, PM");
  const [conversationRawText, setConversationRawText] = useState(defaultDmText);
  const [conversationRedactedText, setConversationRedactedText] = useState("");
  const [conversationConsentConfirmed, setConversationConsentConfirmed] = useState(false);
  const [conversationApprovalNote, setConversationApprovalNote] = useState("同意確認とマスキング内容をレビューしました。");

  const [summaryDraft, setSummaryDraft] = useState("");
  const [decisionsDraft, setDecisionsDraft] = useState("");
  const [questionsDraft, setQuestionsDraft] = useState("");
  const [actionsDraft, setActionsDraft] = useState("");
  const [requirementBackgroundDraft, setRequirementBackgroundDraft] = useState("");
  const [requirementGoalDraft, setRequirementGoalDraft] = useState("");
  const [userStoriesDraft, setUserStoriesDraft] = useState("");
  const [functionalRequirementsDraft, setFunctionalRequirementsDraft] = useState("");
  const [nonFunctionalRequirementsDraft, setNonFunctionalRequirementsDraft] = useState("");
  const [acceptanceCriteriaDraft, setAcceptanceCriteriaDraft] = useState("");
  const [outOfScopeDraft, setOutOfScopeDraft] = useState("");
  const [requirementOpenQuestionsDraft, setRequirementOpenQuestionsDraft] = useState("");
  const [risksDraft, setRisksDraft] = useState("");
  const [requirementApprovalNote, setRequirementApprovalNote] = useState(defaultRequirementApprovalNote);
  const [issueTitleDraft, setIssueTitleDraft] = useState("");
  const [issueBodyDraft, setIssueBodyDraft] = useState("");
  const [issueAcceptanceDraft, setIssueAcceptanceDraft] = useState("");
  const [issueLabelsDraft, setIssueLabelsDraft] = useState("");
  const [reconciliationIssueNumber, setReconciliationIssueNumber] = useState("");
  const [reconciliationIssueUrl, setReconciliationIssueUrl] = useState("");
  const [reconciliationNote, setReconciliationNote] = useState("");
  const [reconciliationApprover, setReconciliationApprover] = useState("");
  const [reconciliationRetryReasonTemplate, setReconciliationRetryReasonTemplate] =
    useState<RetryReasonTemplate>("github_issue_absence_confirmed");
  const [reconciliationMatches, setReconciliationMatches] = useState<GitHubReconciliationMatch[]>([]);
  const [reconciliationSearchSummary, setReconciliationSearchSummary] = useState<GitHubReconciliationSearchSummary | null>(null);
  const [openApiTitleDraft, setOpenApiTitleDraft] = useState("");
  const [openApiContentDraft, setOpenApiContentDraft] = useState("");

  const selectedProject = useMemo(
    () => projects.find((project) => project.id === selectedProjectId) ?? null,
    [projects, selectedProjectId],
  );
  const githubIntegration = useMemo(
    () => integrationAccounts.find((account) => account.provider === "github") ?? null,
    [integrationAccounts],
  );

  useEffect(() => {
    setClientReady(true);
    void loadProjects();
    void loadAuthSessions();
  }, []);

  useEffect(() => {
    function handleAuthRequired(event: Event) {
      const detail = (event as CustomEvent<AuthRequiredEventDetail>).detail;
      lockForReauth(detail);
    }

    window.addEventListener(authRequiredEventName, handleAuthRequired);
    return () => window.removeEventListener(authRequiredEventName, handleAuthRequired);
  }, []);

  useEffect(() => {
    if (authLocked) authLockHeadingRef.current?.focus();
  }, [authLocked]);

  useEffect(() => {
    if (!selectedProjectId) return;
    setIntegrationAccounts([]);
    setProjectMemberships([]);
    setGithubInstallationUrl("");
    setConversationImports([]);
    setSelectedConversationImport(null);
    setConversationSummaryDraft(null);
    setConversationSummaryReview(null);
    setConversationSafetyFlags([]);
    setConversationRedactionSuggestions([]);
    void loadMeetings(selectedProjectId);
    void loadIntegrations(selectedProjectId);
    void loadProjectMemberships(selectedProjectId);
    void loadConversationImports(selectedProjectId);
    void loadQueueHealth({ announce: false });
  }, [selectedProjectId]);

  useEffect(() => {
    setConversationSummaryDraftEdit(conversationDraftEditFormFromDraft(conversationSummaryDraft));
    if (conversationSummaryDraft?.id) {
      void loadConversationSummaryReview(conversationSummaryDraft.id);
    } else {
      setConversationSummaryReview(null);
    }
  }, [conversationSummaryDraft]);

  function setApiError(message: string) {
    setError(message);
    setStatusMessage("APIエラー");
  }

  function clearSensitiveWorkspaceState() {
    setProjects([]);
    setSelectedProjectId("");
    setMeetings([]);
    setSelectedMeeting(null);
    setMinutes(null);
    setRequirement(null);
    setIssueDraft(null);
    setOpenApiDraft(null);
    setOpenApiValidation(null);
    setLastJob(null);
    setLastReview(null);
    setOpenApiReview(null);
    setConversationSummaryReview(null);
    setIntegrationAccounts([]);
    setProjectMemberships([]);
    setAuthSessions([]);
    setAuthSessionMeta(null);
    setGithubInstallationUrl("");
    setConversationImports([]);
    setSelectedConversationImport(null);
    setConversationSummaryDraft(null);
    setConversationSafetyFlags([]);
    setConversationRedactionSuggestions([]);
    setRawText("");
    setConversationRawText("");
    setConversationRedactedText("");
    setConversationConsentConfirmed(false);
    clearMinutesDrafts();
    clearRequirementDrafts();
    clearIssueDrafts();
    clearOpenApiDrafts();
  }

  function lockForReauth(detail?: Partial<AuthRequiredEventDetail>) {
    authLockedRef.current = true;
    clearSensitiveWorkspaceState();
    setAuthLocked(true);
    setAuthLockCode(detail?.code ?? "authentication_required");
    setAuthLockMessage(authRecoveryMessage(detail));
    setError("");
    setLoading(false);
    setStatusMessage("再ログインが必要です");
  }

  function retryAuth() {
    restoreAuthState();
    authLockedRef.current = false;
    setAuthLocked(false);
    setAuthLockCode("");
    setAuthLockMessage("");
    setStatusMessage("認証状態を再確認中");
    void loadProjects();
    void loadQueueHealth({ announce: false });
    void loadAuthSessions();
  }

  async function loadAuthSessions() {
    if (!hasBearerAuth()) {
      setAuthSessions([]);
      setAuthSessionMeta(null);
      return;
    }

    const { data, error: apiError } = await apiClient.GET("/auth/sessions");
    if (authLockedRef.current) return;
    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setAuthSessions(data.data);
    setAuthSessionMeta(data.meta);
  }

  async function logoutCurrentSession() {
    if (!window.confirm("この端末からログアウトします。")) return;

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.DELETE("/auth/sessions/current");
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    if (data?.data) {
      setAuthSessions((current) => current.map((session) => (session.id === data.data.id ? data.data : session)));
    }
    clearAuthState();
    lockForReauth({ code: "session_revoked", message: "Authentication session has been revoked.", status: 200 });
  }

  async function revokeAuthSession(authSession: AuthSession) {
    if (authSession.current) {
      await logoutCurrentSession();
      return;
    }

    if (!window.confirm("選択したログインセッションを失効します。")) return;

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.DELETE("/auth/sessions/{auth_session_id}", {
      params: { path: { auth_session_id: authSession.id } },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setAuthSessions((current) => current.map((session) => (session.id === data.data.id ? data.data : session)));
    setStatusMessage("他のセッションを失効しました");
  }

  async function logoutEverywhere() {
    if (!window.confirm("すべての端末からログアウトします。")) return;

    setLoading(true);
    setError("");
    const { error: apiError } = await apiClient.POST("/auth/logout-everywhere");
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    clearAuthState();
    lockForReauth({ code: "session_version_stale", message: "Authentication session is no longer current.", status: 200 });
  }

  async function loadProjects() {
    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.GET("/projects");
    if (authLockedRef.current) {
      setLoading(false);
      return;
    }
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const loadedProjects = data.data;
    setProjects(loadedProjects);
    setSelectedProjectId((current) => current || loadedProjects[0]?.id || "");
    setStatusMessage(loadedProjects.length > 0 ? "プロジェクトを読み込みました" : "プロジェクト未作成");
  }

  async function loadMeetings(projectId: string) {
    setError("");
    const { data, error: apiError } = await apiClient.GET("/projects/{project_id}/meetings", {
      params: { path: { project_id: projectId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setMeetings(data.data);
    setSelectedMeeting((current) => current ?? data.data[0] ?? null);
  }

  async function loadIntegrations(projectId: string) {
    const { data } = await apiClient.GET("/projects/{project_id}/integrations", {
      params: { path: { project_id: projectId } },
    });

    setIntegrationAccounts(data?.data ?? []);
  }

  async function loadProjectMemberships(projectId: string) {
    const { data, error: apiError } = await apiClient.GET("/projects/{project_id}/memberships", {
      params: {
        path: { project_id: projectId },
        query: { status: "all" },
      },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setProjectMemberships(data.data);
  }

  async function createProjectMembership() {
    if (!selectedProjectId) {
      setApiError("プロジェクトを先に作成または選択してください。");
      return;
    }

    const actorId = newMemberActorId.trim();
    if (!actorId) {
      setApiError("メンバーIDを入力してください。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/projects/{project_id}/memberships", {
      params: { path: { project_id: selectedProjectId } },
      body: {
        actor_id: actorId,
        role: newMemberRole,
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setProjectMemberships((current) => [data.data, ...current.filter((membership) => membership.id !== data.data.id)]);
    setNewMemberActorId("");
    setNewMemberRole("viewer");
    setStatusMessage("メンバーを追加しました");
  }

  async function updateProjectMembershipRole(membership: ProjectMembership, role: ProjectMembershipRole) {
    if (!selectedProjectId) return;

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.PATCH("/projects/{project_id}/memberships/{membership_id}", {
      params: { path: { project_id: selectedProjectId, membership_id: membership.id } },
      body: { role },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setProjectMemberships((current) => current.map((item) => (item.id === data.data.id ? data.data : item)));
    setStatusMessage("メンバー権限を変更しました");
  }

  async function revokeProjectMembership(membership: ProjectMembership) {
    if (!selectedProjectId) return;
    if (!window.confirm(`${membership.actor_id} のプロジェクト権限を失効します。`)) return;

    setLoading(true);
    setError("");
    const { error: apiError } = await apiClient.DELETE("/projects/{project_id}/memberships/{membership_id}", {
      params: { path: { project_id: selectedProjectId, membership_id: membership.id } },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setProjectMemberships((current) =>
      current.map((item) => (item.id === membership.id ? { ...item, status: "revoked" as const, updated_at: new Date().toISOString() } : item)),
    );
    setStatusMessage("メンバー権限を失効しました");
  }

  async function loadConversationImports(projectId: string) {
    const { data, error: apiError } = await apiClient.GET("/projects/{project_id}/conversation-imports", {
      params: { path: { project_id: projectId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const imports = data.data;
    setConversationImports(imports);
    const nextSelected = imports.find((item) => item.id === selectedConversationImport?.id) ?? imports[0] ?? null;
    setSelectedConversationImport(nextSelected);
    setConversationSummaryDraft(nextSelected?.latest_summary_draft ?? null);
  }

  async function refreshConversationImport(conversationImportId: string) {
    const { data, error: apiError } = await apiClient.GET("/conversation-imports/{conversation_import_id}", {
      params: { path: { conversation_import_id: conversationImportId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return null;
    }

    applyConversationImport(data.data);
    return data.data;
  }

  async function loadQueueHealth(options: { announce?: boolean } = {}) {
    const announce = options.announce !== false;
    if (!selectedProjectId) {
      setQueueHealthLoading(false);
      return;
    }

    setQueueHealthLoading(true);
    if (announce) setError("");

    try {
      const { data, error: apiError } = await apiClient.GET("/operations/queue-health", {
        params: { query: { project_id: selectedProjectId } },
      });
      if (authLockedRef.current) {
        setQueueHealthLoading(false);
        return;
      }
      setQueueHealthLoading(false);

      if (apiError) {
        if (announce) setApiError(errorMessage(apiError));
        return;
      }

      setQueueHealth(normalizeQueueHealth(data.data));
      if (announce) setStatusMessage("運用状態を更新しました");
    } catch {
      setQueueHealthLoading(false);
      if (announce) setApiError("運用状態を取得できませんでした。");
    }
  }

  function failedJobRetryReasonTemplate(job: FailedJobSample): FailedJobRetryReasonTemplate {
    return (
      failedJobRetryReasonTemplates[job.failed_job_id] ??
      job.operations.retry_reason_templates?.[0] ??
      "operator_confirmed_safe_retry"
    );
  }

  function failedJobDiscardReasonTemplate(job: FailedJobSample): FailedJobDiscardReasonTemplate {
    return (
      failedJobDiscardReasonTemplates[job.failed_job_id] ??
      job.operations.discard_reason_templates?.[0] ??
      "manually_resolved"
    );
  }

  function updateFailedJobRetryReasonTemplate(failedJobId: number, reasonTemplate: FailedJobRetryReasonTemplate) {
    setFailedJobRetryReasonTemplates((current) => ({ ...current, [failedJobId]: reasonTemplate }));
  }

  function updateFailedJobDiscardReasonTemplate(failedJobId: number, reasonTemplate: FailedJobDiscardReasonTemplate) {
    setFailedJobDiscardReasonTemplates((current) => ({ ...current, [failedJobId]: reasonTemplate }));
  }

  function updateFailedJobDiscardConfirmation(failedJobId: number, checked: boolean) {
    setFailedJobDiscardConfirmations((current) => ({ ...current, [failedJobId]: checked }));
  }

  function failedJobDiscardApproval(job: FailedJobSample) {
    return job.operations.discard_approval ?? null;
  }

  function updateFailedJobApprovalNote(approvalId: string, value: string) {
    setFailedJobApprovalNotes((current) => ({ ...current, [approvalId]: value }));
  }

  function updateFailedJobRejectionReason(approvalId: string, value: string) {
    setFailedJobRejectionReasons((current) => ({ ...current, [approvalId]: value }));
  }

  async function requestFailedJobDiscardApproval(job: FailedJobSample) {
    if (!selectedProjectId) {
      setApiError("プロジェクトを先に作成または選択してください。");
      return;
    }

    if (!failedJobDiscardConfirmations[job.failed_job_id]) {
      setApiError("破棄承認を依頼する前にリスク確認が必要です。");
      return;
    }

    setFailedJobOperationId(job.failed_job_id);
    setError("");

    try {
      const { error: apiError } = await apiClient.POST("/operations/failed-jobs/{failed_job_id}/discard-approval-requests", {
        params: {
          path: { failed_job_id: job.failed_job_id },
          query: { project_id: selectedProjectId },
        },
        body: { reason_template: failedJobDiscardReasonTemplate(job), discard_safety_confirmed: true },
      });

      if (apiError) {
        setApiError(errorMessage(apiError));
        return;
      }

      setStatusMessage("破棄承認を依頼しました");
      await loadQueueHealth({ announce: false });
    } catch {
      setApiError("破棄承認を依頼できませんでした。");
    } finally {
      setFailedJobOperationId(null);
    }
  }

  async function resolveFailedJobDiscardApproval(approval: FailedJobDiscardApproval, resolution: "approve" | "reject") {
    if (!selectedProjectId) {
      setApiError("プロジェクトを先に作成または選択してください。");
      return;
    }

    const note = resolution === "approve" ? failedJobApprovalNotes[approval.id]?.trim() : failedJobRejectionReasons[approval.id]?.trim();
    if (!note) {
      setApiError(resolution === "approve" ? "承認コメントが必要です。" : "却下理由が必要です。");
      return;
    }

    setFailedJobOperationId(approval.failed_job_id);
    setError("");

    try {
      const { error: apiError } =
        resolution === "approve"
          ? await apiClient.POST("/operations/failed-job-discard-approvals/{approval_id}/approve", {
              params: {
                path: { approval_id: approval.id },
                query: { project_id: selectedProjectId },
              },
              body: { approval_note: note },
            })
          : await apiClient.POST("/operations/failed-job-discard-approvals/{approval_id}/reject", {
              params: {
                path: { approval_id: approval.id },
                query: { project_id: selectedProjectId },
              },
              body: { rejection_reason: note },
            });

      if (apiError) {
        setApiError(errorMessage(apiError));
        return;
      }

      setStatusMessage(resolution === "approve" ? "破棄承認を承認しました" : "破棄承認を却下しました");
      await loadQueueHealth({ announce: false });
    } catch {
      setApiError(resolution === "approve" ? "破棄承認を承認できませんでした。" : "破棄承認を却下できませんでした。");
    } finally {
      setFailedJobOperationId(null);
    }
  }

  async function operateFailedJob(job: FailedJobSample, action: "retry" | "discard") {
    if (!selectedProjectId) {
      setApiError("プロジェクトを先に作成または選択してください。");
      return;
    }

    if (action === "discard" && !failedJobDiscardConfirmations[job.failed_job_id]) {
      setApiError("破棄前にリスク確認が必要です。");
      return;
    }
    const discardApproval = failedJobDiscardApproval(job);
    if (action === "discard" && discardApproval?.status !== "approved") {
      setApiError("破棄前に二人承認が必要です。");
      return;
    }
    const discardApprovalId = action === "discard" ? discardApproval?.id : undefined;

    setFailedJobOperationId(job.failed_job_id);
    setError("");

    try {
      const { error: apiError } =
        action === "retry"
          ? await apiClient.POST("/operations/failed-jobs/{failed_job_id}/retry", {
              params: {
                path: { failed_job_id: job.failed_job_id },
                query: { project_id: selectedProjectId },
              },
              body: { reason_template: failedJobRetryReasonTemplate(job) },
            })
          : await apiClient.POST("/operations/failed-jobs/{failed_job_id}/discard", {
              params: {
                path: { failed_job_id: job.failed_job_id },
                query: { project_id: selectedProjectId },
              },
              body: {
                reason_template: failedJobDiscardReasonTemplate(job),
                discard_safety_confirmed: true,
                discard_approval_id: discardApprovalId ?? "",
              },
            });

      if (apiError) {
        setApiError(errorMessage(apiError));
        return;
      }

      setStatusMessage(action === "retry" ? "失敗ジョブを再実行しました" : "失敗ジョブを破棄しました");
      await loadQueueHealth({ announce: false });
    } catch {
      setApiError(action === "retry" ? "失敗ジョブを再実行できませんでした。" : "失敗ジョブを破棄できませんでした。");
    } finally {
      setFailedJobOperationId(null);
    }
  }

  async function createProject() {
    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/projects", {
      body: {
        name: projectName,
        github_repo: projectRepo,
        description: "AI PM Platform MVPワークスペース",
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setProjects((current) => [data.data, ...current]);
    setSelectedProjectId(data.data.id);
    setStatusMessage("プロジェクトを作成しました");
  }

  async function saveConversationImport() {
    if (!selectedProjectId) {
      setApiError("プロジェクトを先に作成または選択してください。");
      return;
    }

    if (!conversationConsentConfirmed) {
      setApiError("DM取り込み前に同意確認をチェックしてください。");
      return;
    }

    setLoading(true);
    setError("");
    const redactedText = conversationRedactedText.trim();
    const participantsPayload = conversationParticipantsFromText(conversationParticipants);

    if (selectedConversationImport) {
      const { data, error: apiError } = await apiClient.PATCH("/conversation-imports/{conversation_import_id}", {
        params: { path: { conversation_import_id: selectedConversationImport.id } },
        body: {
          title: conversationTitle,
          raw_text: conversationRawText,
          redacted_text: redactedText,
          participants: participantsPayload,
          consent_confirmed: conversationConsentConfirmed,
          consent_statement_version: conversationConsentStatementVersion,
        },
      });
      setLoading(false);

      if (apiError) {
        setApiError(errorMessage(apiError));
        return;
      }

      applyConversationImport(data.data);
      setConversationSafetyFlags([]);
      setConversationRedactionSuggestions([]);
      setStatusMessage("DMインポートを更新しました");
      return;
    }

    const { data, error: apiError } = await apiClient.POST("/projects/{project_id}/conversation-imports", {
      params: { path: { project_id: selectedProjectId } },
      body: {
        source_type: "discord_dm_paste",
        title: conversationTitle,
        raw_text: conversationRawText,
        redacted_text: redactedText || undefined,
        participants: participantsPayload,
        consent_confirmed: conversationConsentConfirmed,
        consent_statement_version: conversationConsentStatementVersion,
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyConversationImport(data.data);
    setConversationSafetyFlags([]);
    setConversationRedactionSuggestions([]);
    setStatusMessage("DMインポートを保存しました");
  }

  async function scanConversationImport() {
    if (!selectedConversationImport) {
      setApiError("スキャンするDMインポートがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/conversation-imports/{conversation_import_id}/scan", {
      params: { path: { conversation_import_id: selectedConversationImport.id } },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyConversationImport(data.data.conversation_import);
    setConversationSafetyFlags(data.data.safety_flags);
    setConversationRedactionSuggestions(data.data.redaction_suggestions);
    setStatusMessage(data.data.valid ? "DMの安全チェックに合格しました" : "DMの安全チェックで修正が必要です");
  }

  async function generateConversationSummary() {
    if (!selectedConversationImport) {
      setApiError("整理するDMインポートがありません。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("DM整理ドラフトを生成中");
    const { data, error: apiError } = await apiClient.POST("/conversation-imports/{conversation_import_id}/generate-summary", {
      params: { path: { conversation_import_id: selectedConversationImport.id } },
    });

    if (apiError) {
      await loadFailedJob(errorJobId(apiError));
      setLoading(false);
      setApiError(errorMessage(apiError));
      return;
    }

    setLastJob(data.data.job);
    setConversationSummaryDraft(data.data.conversation_summary_draft ?? null);
    await refreshConversationImport(selectedConversationImport.id);
    setLoading(false);
    setStatusMessage("DM整理ドラフトを生成しました");
  }

  async function saveConversationSummaryDraftEdits() {
    if (!conversationSummaryDraft) {
      setApiError("保存するDM整理ドラフトがありません。");
      return;
    }

    if (!canEditConversationSummaryDraft) {
      setApiError("承認済みまたは古い整理ドラフトは編集できません。");
      return;
    }

    if (!conversationSummaryDraftEdit.summary.trim()) {
      setApiError("整理要約を入力してください。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.PATCH("/conversation-summary-drafts/{conversation_summary_draft_id}", {
      params: { path: { conversation_summary_draft_id: conversationSummaryDraft.id } },
      body: {
        summary: conversationSummaryDraftEdit.summary.trim(),
        decisions: conversationDecisionsFromText(conversationSummaryDraftEdit.decisions, conversationSummaryDraft.decisions),
        open_questions: compactLines(conversationSummaryDraftEdit.openQuestions),
        action_items: conversationActionItemsFromText(conversationSummaryDraftEdit.actionItems, conversationSummaryDraft.action_items),
        issue_candidates: conversationIssueCandidatesFromText(conversationSummaryDraftEdit.issueCandidates, conversationSummaryDraft.issue_candidates),
        requirement_candidates: conversationRequirementCandidatesFromText(
          conversationSummaryDraftEdit.requirementCandidates,
          conversationSummaryDraft.requirement_candidates
        ),
        risks: conversationRisksFromText(conversationSummaryDraftEdit.risks, conversationSummaryDraft.risks),
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setConversationSummaryDraft(data.data);
    await refreshConversationImport(data.data.conversation_import_id);
    setStatusMessage("DM整理ドラフトを保存しました");
  }

  async function approveConversationSummary() {
    if (!conversationSummaryDraft) {
      setApiError("承認するDM整理ドラフトがありません。");
      return;
    }

    if (conversationSummaryDraft.status === "needs_revision") {
      setApiError("修正が必要なDM整理ドラフトは承認できません。");
      return;
    }

    if (blockingReviewStatus(conversationSummaryReview?.status)) {
      setApiError("未解決のDM整理レビューがあるため承認できません。");
      return;
    }

    if (!canApproveConversationSummaryDraft) {
      setApiError("承認済みまたは古い整理ドラフトは承認できません。");
      return;
    }

    if (!conversationApprovalNote.trim()) {
      setApiError("承認理由を入力してください。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/conversation-summary-drafts/{conversation_summary_draft_id}/approve", {
      params: { path: { conversation_summary_draft_id: conversationSummaryDraft.id } },
      body: {
        approval_note: conversationApprovalNote.trim(),
        generate_downstream_candidates: true,
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setConversationSummaryDraft(data.data);
    await refreshConversationImport(data.data.conversation_import_id);
    setStatusMessage("DM整理ドラフトを承認しました");
  }

  async function anonymizeConversationImport() {
    if (!selectedConversationImport) {
      setApiError("匿名化するDMインポートがありません。");
      return;
    }

    if (!window.confirm("DMインポートを匿名化し、本文と整理候補を削除します。")) return;

    setLoading(true);
    setError("");
    const { error: apiError } = await apiClient.DELETE("/conversation-imports/{conversation_import_id}", {
      params: { path: { conversation_import_id: selectedConversationImport.id } },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    if (selectedProjectId) await loadConversationImports(selectedProjectId);
    resetConversationImportDraft();
    setStatusMessage("DMインポートを匿名化しました");
  }

  async function startGitHubConnection() {
    if (!selectedProjectId) {
      setApiError("プロジェクトを先に作成または選択してください。");
      return;
    }

    const repository = selectedProject?.github_repo || projectRepo.trim();
    if (!repository) {
      setApiError("GitHubリポジトリを入力してください。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/projects/{project_id}/integrations/github/connect", {
      params: { path: { project_id: selectedProjectId } },
      body: { repository },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setGithubInstallationUrl(data.data.installation_url);
    setStatusMessage("GitHub接続URLを作成しました");
  }

  async function createMeeting() {
    if (!selectedProjectId) {
      setApiError("プロジェクトを先に作成または選択してください。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/projects/{project_id}/meetings", {
      params: { path: { project_id: selectedProjectId } },
      body: {
        title: meetingTitle,
        source_type: sourceType,
        meeting_date: meetingDate || undefined,
        participants: compactLines(participants.replaceAll(",", "\n")),
        raw_text: rawText,
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setMeetings((current) => [data.data, ...current]);
    setSelectedMeeting(data.data);
    setMinutes(null);
    setRequirement(null);
    setIssueDraft(null);
    setOpenApiDraft(null);
    clearMinutesDrafts();
    clearRequirementDrafts();
    clearIssueDrafts();
    clearOpenApiDrafts();
    setStatusMessage("会議を保存しました");
  }

  async function generateMinutes() {
    if (!selectedMeeting) {
      setApiError("会議を先に保存してください。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("議事録を生成中");
    const { data, error: apiError } = await apiClient.POST("/meetings/{meeting_id}/generate-minutes", {
      params: { path: { meeting_id: selectedMeeting.id } },
    });

    if (apiError) {
      await loadFailedJob(errorJobId(apiError));
      setLoading(false);
      setApiError(errorMessage(apiError));
      return;
    }

    await loadJobAndMinutes(data.data.job_id);
    setLoading(false);
  }

  async function loadFailedJob(jobId?: string) {
    if (!jobId) return;
    await loadJob(jobId);
  }

  async function loadJob(jobId: string) {
    const { data } = await apiClient.GET("/jobs/{job_id}", {
      params: { path: { job_id: jobId } },
    });
    if (data) {
      setLastJob(data.data);
      return data.data;
    }

    return null;
  }

  async function loadJobAndMinutes(jobId: string) {
    const { data, error: apiError } = await apiClient.GET("/jobs/{job_id}", {
      params: { path: { job_id: jobId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const job = data.data;
    setLastJob(job);
    if (job.status === "failed") {
      setApiError(displayMessage(job.safe_error_detail) || "議事録生成に失敗しました。");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("議事録生成ジョブは完了しましたが、対象IDがありません");
      return;
    }

    const minutesResult = await apiClient.GET("/minutes/{minutes_id}", {
      params: { path: { minutes_id: job.target_id } },
    });

    if (minutesResult.error) {
      setApiError(errorMessage(minutesResult.error));
      return;
    }

    applyMinutes(minutesResult.data.data);
    setRequirement(null);
    setIssueDraft(null);
    setOpenApiDraft(null);
    clearRequirementDrafts();
    clearIssueDrafts();
    clearOpenApiDrafts();
    setStatusMessage("議事録を生成しました");
  }

  async function saveMinutes() {
    if (!minutes) {
      setApiError("保存する議事録がありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.PATCH("/minutes/{minutes_id}", {
      params: { path: { minutes_id: minutes.id } },
      body: {
        summary: summaryDraft,
        decisions: compactLines(decisionsDraft).map((text) => ({ text })),
        open_questions: compactLines(questionsDraft),
        action_items: compactLines(actionsDraft).map((text) => ({ text, status: "open" as const })),
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyMinutes(data.data);
    setStatusMessage("議事録を保存しました");
  }

  async function approveMinutes() {
    if (!minutes) {
      setApiError("承認する議事録がありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/minutes/{minutes_id}/approve", {
      params: { path: { minutes_id: minutes.id } },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyMinutes(data.data);
    setStatusMessage("議事録を承認しました");
  }

  async function generateRequirement() {
    if (!minutes) {
      setApiError("要件定義の生成対象となる議事録がありません。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("要件定義を生成中");
    const { data, error: apiError } = await apiClient.POST("/minutes/{minutes_id}/generate-requirement", {
      params: { path: { minutes_id: minutes.id } },
    });

    if (apiError) {
      await loadFailedJob(errorJobId(apiError));
      setLoading(false);
      setApiError(errorMessage(apiError));
      return;
    }

    await loadJobAndRequirement(data.data.job_id);
    setLoading(false);
  }

  async function loadJobAndRequirement(jobId: string) {
    const { data, error: apiError } = await apiClient.GET("/jobs/{job_id}", {
      params: { path: { job_id: jobId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const job = data.data;
    setLastJob(job);
    if (job.status === "failed") {
      setApiError(displayMessage(job.safe_error_detail) || "要件定義生成に失敗しました。");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("要件定義生成ジョブは完了しましたが、対象IDがありません");
      return;
    }

    const requirementResult = await apiClient.GET("/requirements/{requirement_id}", {
      params: { path: { requirement_id: job.target_id } },
    });

    if (requirementResult.error) {
      setApiError(errorMessage(requirementResult.error));
      return;
    }

    applyRequirement(requirementResult.data.data, { resetDownstream: true });
    await loadRequirementReviews(requirementResult.data.data.id);
    await loadRequirementHistory(requirementResult.data.data.id);
    setStatusMessage("要件定義を生成しました");
  }

  async function saveRequirement() {
    if (!requirement) {
      setApiError("保存する要件定義がありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.PATCH("/requirements/{requirement_id}", {
      params: { path: { requirement_id: requirement.id } },
      body: {
        background: requirementBackgroundDraft,
        goal: requirementGoalDraft,
        user_stories: compactLines(userStoriesDraft),
        functional_requirements: compactLines(functionalRequirementsDraft),
        non_functional_requirements: compactLines(nonFunctionalRequirementsDraft),
        acceptance_criteria: compactLines(acceptanceCriteriaDraft),
        out_of_scope: compactLines(outOfScopeDraft),
        open_questions: compactLines(requirementOpenQuestionsDraft),
        risks: compactLines(risksDraft),
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyRequirement(data.data, { staleDownstream: requirement.status === "approved" && data.data.status === "needs_changes" });
    await loadRequirementReviews(data.data.id);
    await loadRequirementHistory(data.data.id);
    setStatusMessage("要件定義を保存しました");
  }

  async function approveRequirement() {
    if (!requirement) {
      setApiError("承認する要件定義がありません。");
      return;
    }

    if (!requirementApprovalNote.trim()) {
      setApiError("要件定義の承認コメントを入力してください。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/requirements/{requirement_id}/approve", {
      params: { path: { requirement_id: requirement.id } },
      body: {
        approval_note: requirementApprovalNote.trim(),
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyRequirement(data.data);
    await loadRequirementReviews(data.data.id);
    await loadRequirementHistory(data.data.id);
    setStatusMessage("要件定義を承認しました");
  }

  async function generateIssueDraft() {
    if (!requirement) {
      setApiError("Issueドラフトの生成対象となる要件定義がありません。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("Issueドラフトを生成中");
    const { data, error: apiError } = await apiClient.POST("/requirements/{requirement_id}/generate-issue-draft", {
      params: { path: { requirement_id: requirement.id } },
    });

    if (apiError) {
      await loadFailedJob(errorJobId(apiError));
      setLoading(false);
      setApiError(errorMessage(apiError));
      return;
    }

    await loadJobAndIssueDraft(data.data.job_id);
    setLoading(false);
  }

  async function loadJobAndIssueDraft(jobId: string) {
    const { data, error: apiError } = await apiClient.GET("/jobs/{job_id}", {
      params: { path: { job_id: jobId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const job = data.data;
    setLastJob(job);
    if (job.status === "failed") {
      setApiError(displayMessage(job.safe_error_detail) || "Issueドラフト生成に失敗しました。");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("Issueドラフト生成ジョブは完了しましたが、対象IDがありません");
      return;
    }

    const issueDraftResult = await apiClient.GET("/issue-drafts/{issue_draft_id}", {
      params: { path: { issue_draft_id: job.target_id } },
    });

    if (issueDraftResult.error) {
      setApiError(errorMessage(issueDraftResult.error));
      return;
    }

    applyIssueDraft(issueDraftResult.data.data);
    setStatusMessage("Issueドラフトを生成しました");
  }

  async function saveIssueDraft() {
    if (!issueDraft) {
      setApiError("保存するIssueドラフトがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.PATCH("/issue-drafts/{issue_draft_id}", {
      params: { path: { issue_draft_id: issueDraft.id } },
      body: {
        title: issueTitleDraft,
        body: issueBodyDraft,
        acceptance_criteria: compactLines(issueAcceptanceDraft),
        labels: compactLines(issueLabelsDraft.replaceAll(",", "\n")),
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyIssueDraft(data.data);
    setStatusMessage("Issueドラフトを保存しました");
  }

  async function approveIssueDraft() {
    if (!issueDraft) {
      setApiError("承認するIssueドラフトがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.PATCH("/issue-drafts/{issue_draft_id}", {
      params: { path: { issue_draft_id: issueDraft.id } },
      body: {
        title: issueTitleDraft,
        body: issueBodyDraft,
        acceptance_criteria: compactLines(issueAcceptanceDraft),
        labels: compactLines(issueLabelsDraft.replaceAll(",", "\n")),
        status: "approved",
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyIssueDraft(data.data);
    setStatusMessage("Issueドラフトを承認しました");
  }

  async function publishIssueDraft() {
    if (!issueDraft) {
      setApiError("公開するIssueドラフトがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const idempotencyKey = `issue-${issueDraft.id}-${Date.now()}`;
    const { data, error: apiError } = await apiClient.POST("/issue-drafts/{issue_draft_id}/publish-github", {
      params: {
        header: { "Idempotency-Key": idempotencyKey },
        path: { issue_draft_id: issueDraft.id },
      },
    });

    const refreshedIssueDraft = await apiClient.GET("/issue-drafts/{issue_draft_id}", {
      params: { path: { issue_draft_id: issueDraft.id } },
    });
    if (refreshedIssueDraft.data) applyIssueDraft(refreshedIssueDraft.data.data);

    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setStatusMessage(data.data.status === "published" ? "GitHub Issueを公開しました" : "GitHub Issueを公開中");
  }

  async function refreshIssueDraft(issueDraftId: string) {
    const { data, error: apiError } = await apiClient.GET("/issue-drafts/{issue_draft_id}", {
      params: { path: { issue_draft_id: issueDraftId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return null;
    }

    applyIssueDraft(data.data);
    return data.data;
  }

  async function reconcileGitHubPublish() {
    if (!issueDraft) {
      setApiError("復旧確認するIssueドラフトがありません。");
      return;
    }

    setLoading(true);
    setError("");
    setReconciliationMatches([]);
    setStatusMessage("GitHub公開を照合中");
    const idempotencyKey = `github-reconcile-${issueDraft.id}-${Date.now()}`;
    const { data, error: apiError } = await apiClient.POST("/issue-drafts/{issue_draft_id}/reconcile-github-publish", {
      params: {
        header: { "Idempotency-Key": idempotencyKey },
        path: { issue_draft_id: issueDraft.id },
      },
    });

    if (apiError) {
      await loadFailedJob(errorJobId(apiError));
      await refreshIssueDraft(issueDraft.id);
      setLoading(false);
      setApiError(errorMessage(apiError));
      return;
    }

    await loadJob(data.data.job_id);
    await refreshIssueDraft(issueDraft.id);
    const matches = data.data.status === "review_required" ? (data.data.matches ?? []) : [];
    setReconciliationMatches(matches);
    setReconciliationSearchSummary(
      data.data.status === "review_required"
        ? {
            search_total_count: data.data.search_total_count,
            search_incomplete_results: data.data.search_incomplete_results,
            search_result_limit: data.data.search_result_limit,
            search_has_more_results: data.data.search_has_more_results,
          }
        : null,
    );
    setLoading(false);
    setStatusMessage(data.data.status === "reconciled" ? "GitHub公開の照合が完了しました" : "GitHub公開の照合に確認が必要です");
  }

  async function resolveGitHubReconciliation(resolutionAction: GitHubReconciliationAction) {
    if (!issueDraft) {
      setApiError("復旧処理するIssueドラフトがありません。");
      return;
    }

    const resolutionNote = reconciliationNote.trim();
    if (!resolutionNote) {
      setApiError("解決メモを入力してください。");
      return;
    }

    const body: components["schemas"]["ResolveGitHubReconciliationRequest"] = {
      resolution_action: resolutionAction,
      resolution_note: resolutionNote,
    };

    if (resolutionAction === "link_existing_issue") {
      const issueNumber = Number(reconciliationIssueNumber.trim());
      const issueUrl = reconciliationIssueUrl.trim();

      if (!Number.isInteger(issueNumber) || issueNumber < 1) {
        setApiError("GitHub Issue番号は1以上の整数で入力してください。");
        return;
      }

      if (!issueUrl) {
        setApiError("GitHub Issue URLを入力してください。");
        return;
      }

      const issueUrlValidationError = githubIssueUrlValidationError(issueUrl, issueNumber, selectedProject?.github_repo);
      if (issueUrlValidationError) {
        setApiError(issueUrlValidationError);
        return;
      }

      body.github_issue_number = issueNumber;
      body.github_issue_url = issueUrl;
    }

    if (resolutionAction === "approve_retry") {
      const approver = reconciliationApprover.trim();
      if (!approver) {
        setApiError("再試行の承認者を入力してください。");
        return;
      }

      body.resolution_approver = approver;
      body.retry_reason_template = reconciliationRetryReasonTemplate;
    }

    setLoading(true);
    setError("");
    const idempotencyKey = `github-reconcile-resolve-${issueDraft.id}-${resolutionAction}-${Date.now()}`;
    const { data, error: apiError } = await apiClient.POST("/issue-drafts/{issue_draft_id}/resolve-github-reconciliation", {
      params: {
        header: { "Idempotency-Key": idempotencyKey },
        path: { issue_draft_id: issueDraft.id },
      },
      body,
    });

    if (apiError) {
      await loadFailedJob(errorJobId(apiError));
      await refreshIssueDraft(issueDraft.id);
      setLoading(false);
      setApiError(errorMessage(apiError));
      return;
    }

    await loadJob(data.data.job_id);
    await refreshIssueDraft(issueDraft.id);
    setLoading(false);
    setReconciliationNote("");
    setReconciliationMatches([]);
    setStatusMessage(data.data.status === "manually_reconciled" ? "GitHub Issueに紐付けました" : "GitHub公開の再試行を承認しました");
  }

  async function generateOpenApiDraft() {
    if (!requirement) {
      setApiError("OpenAPIドラフトの生成対象となる要件定義がありません。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("OpenAPIドラフトを生成中");
    const { data, error: apiError } = await apiClient.POST("/requirements/{requirement_id}/generate-openapi-draft", {
      params: { path: { requirement_id: requirement.id } },
    });

    if (apiError) {
      await loadFailedJob(errorJobId(apiError));
      setLoading(false);
      setApiError(errorMessage(apiError));
      return;
    }

    await loadJobAndOpenApiDraft(data.data.job_id);
    setLoading(false);
  }

  async function loadJobAndOpenApiDraft(jobId: string) {
    const { data, error: apiError } = await apiClient.GET("/jobs/{job_id}", {
      params: { path: { job_id: jobId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const job = data.data;
    setLastJob(job);
    if (job.status === "failed") {
      setApiError(displayMessage(job.safe_error_detail) || "OpenAPIドラフト生成に失敗しました。");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("OpenAPIドラフト生成ジョブは完了しましたが、対象IDがありません");
      return;
    }

    const openApiDraftResult = await apiClient.GET("/openapi-drafts/{openapi_draft_id}", {
      params: { path: { openapi_draft_id: job.target_id } },
    });

    if (openApiDraftResult.error) {
      setApiError(errorMessage(openApiDraftResult.error));
      return;
    }

    applyOpenApiDraft(openApiDraftResult.data.data);
    setStatusMessage("OpenAPIドラフトを生成しました");
  }

  async function saveOpenApiDraft() {
    if (!openApiDraft) {
      setApiError("保存するOpenAPIドラフトがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.PATCH("/openapi-drafts/{openapi_draft_id}", {
      params: { path: { openapi_draft_id: openApiDraft.id } },
      body: {
        title: openApiTitleDraft,
        content: openApiContentDraft,
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyOpenApiDraft(data.data);
    setOpenApiValidation(null);
    setOpenApiReview(null);
    setStatusMessage("OpenAPIドラフトを保存しました");
  }

  async function validateOpenApiDraft() {
    if (!openApiDraft) {
      setApiError("検証するOpenAPIドラフトがありません。");
      return;
    }

    setLoading(true);
    setError("");
    setOpenApiValidation(null);
    const savedDraft = await apiClient.PATCH("/openapi-drafts/{openapi_draft_id}", {
      params: { path: { openapi_draft_id: openApiDraft.id } },
      body: {
        title: openApiTitleDraft,
        content: openApiContentDraft,
      },
    });

    if (savedDraft.error) {
      setLoading(false);
      setApiError(errorMessage(savedDraft.error));
      return;
    }

    applyOpenApiDraft(savedDraft.data.data);
    const validationResult = await apiClient.POST("/openapi-drafts/{openapi_draft_id}/validate", {
      params: { path: { openapi_draft_id: savedDraft.data.data.id } },
    });

    if (validationResult.error) {
      setLoading(false);
      setApiError(errorMessage(validationResult.error));
      return;
    }

    setOpenApiValidation(validationResult.data.data);
    const refreshedDraft = await apiClient.GET("/openapi-drafts/{openapi_draft_id}", {
      params: { path: { openapi_draft_id: savedDraft.data.data.id } },
    });

    if (refreshedDraft.error) {
      setLoading(false);
      setApiError(errorMessage(refreshedDraft.error));
      return;
    }

    applyOpenApiDraft(refreshedDraft.data.data);
    await loadOpenApiReview(refreshedDraft.data.data.id);
    setStatusMessage(validationResult.data.data.valid ? "OpenAPI検証に成功しました" : "OpenAPI検証に失敗しました");
    setLoading(false);
  }

  async function loadOpenApiReview(openApiDraftId: string) {
    const { data, error: apiError } = await apiClient.GET("/reviews", {
      params: {
        query: {
          target_type: "openapi_draft",
          target_id: openApiDraftId,
        },
      },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const validatorReview = data.data.find((review) => review.reviewer_role === "OpenAPI Validator") ?? null;
    setOpenApiReview(validatorReview);
  }

  async function loadConversationSummaryReview(conversationSummaryDraftId: string) {
    const { data, error: apiError } = await apiClient.GET("/reviews", {
      params: {
        query: {
          target_type: "conversation_summary_draft",
          target_id: conversationSummaryDraftId,
        },
      },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    const review = data.data.find((item) => blockingReviewStatus(item.status)) ?? data.data[0] ?? null;
    setConversationSummaryReview(review);
  }

  async function loadRequirementReviews(requirementId: string) {
    const { data, error: apiError } = await apiClient.GET("/reviews", {
      params: {
        query: {
          target_type: "requirement",
          target_id: requirementId,
        },
      },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setRequirementReviews(data.data);
  }

  async function loadRequirementHistory(requirementId: string) {
    const { data, error: apiError } = await apiClient.GET("/requirements/{requirement_id}/history", {
      params: { path: { requirement_id: requirementId } },
    });

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setRequirementHistory(data.data);
  }

  async function requestConversationSummaryReview() {
    if (!conversationSummaryDraft) {
      setApiError("レビュー対象のDM整理ドラフトがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/reviews", {
      body: {
        target_type: "conversation_summary_draft",
        target_id: conversationSummaryDraft.id,
        reviewer_role: "Product Manager",
        framework: ["G-STACK", "HEART", "ISO25010"],
        positives: ["DM整理ドラフトが編集可能な状態で保存されている。"],
        improvements: ["承認前に誤要約、抜け漏れ、Issue候補、要件候補を確認する。"],
        priority: ["P1: DM由来情報を下流へ渡す前にレビュー状態を確認する。"],
        next_actions: ["整理要約、決定事項、未解決事項、Issue候補、要件候補、リスクを確認する。"],
        issue_numbers: ["#37"],
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setConversationSummaryReview(data.data);
    setStatusMessage("DM整理レビューを依頼しました");
  }

  async function resolveConversationSummaryReview() {
    if (!conversationSummaryReview) {
      setApiError("解決するDM整理レビューがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/reviews/{review_id}/resolve-action", {
      params: { path: { review_id: conversationSummaryReview.id } },
      body: {
        resolution_note: "DM整理ドラフトを確認し、承認ブロッカーを解消しました。",
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setConversationSummaryReview(data.data);
    setStatusMessage("DM整理レビューを解決しました");
  }

  async function requestMinutesReview() {
    if (!minutes) {
      setApiError("レビュー対象の議事録がありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/reviews", {
      body: {
        target_type: "minutes",
        target_id: minutes.id,
        reviewer_role: "Product Manager",
        framework: ["G-STACK", "ISO25010"],
        positives: ["議事録ドラフトが生成され、保存されている。"],
        improvements: ["要件定義を生成する前に人間のレビューが必要。"],
        priority: ["P0: 要件定義生成前に議事録を承認する。"],
        next_actions: ["要約、決定事項、未解決事項、アクション項目を確認する。"],
        issue_numbers: ["#2"],
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setLastReview(data.data);
    setStatusMessage("レビューを依頼しました");
  }

  async function requestRequirementReview() {
    if (!requirement) {
      setApiError("レビュー対象の要件定義がありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/reviews", {
      body: {
        target_type: "requirement",
        target_id: requirement.id,
        reviewer_role: "Product Manager",
        framework: ["G-STACK", "MoSCoW", "ISO25010"],
        positives: ["承認済み議事録から要件定義ドラフトが生成されている。"],
        improvements: ["GitHub Issue生成前に未解決事項を解消する必要がある。"],
        priority: ["P0: Issue生成前に要件の曖昧さを解消する。"],
        next_actions: ["背景、目的、受け入れ条件、未解決事項、リスクを確認する。"],
        issue_numbers: ["#3"],
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setLastReview(data.data);
    setRequirementReviews((current) => [data.data, ...current.filter((review) => review.id !== data.data.id)]);
    await loadRequirementHistory(requirement.id);
    setStatusMessage("要件レビューを依頼しました");
  }

  async function resolveRequirementReview() {
    if (!requirement || !requirementReviewToResolve) {
      setApiError("解決する要件レビューがありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/reviews/{review_id}/resolve-action", {
      params: { path: { review_id: requirementReviewToResolve.id } },
      body: { resolution_note: "要件定義レビューの指摘を確認し、未決事項を解消しました。" },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setLastReview(data.data);
    setRequirementReviews((current) => current.map((review) => (review.id === data.data.id ? data.data : review)));
    await loadRequirementHistory(requirement.id);
    setStatusMessage("要件レビューを解決しました");
  }

  function selectMeeting(meeting: Meeting) {
    setSelectedMeeting(meeting);
    setMinutes(null);
    setRequirement(null);
    setIssueDraft(null);
    setOpenApiDraft(null);
    clearMinutesDrafts();
    clearRequirementDrafts();
    clearIssueDrafts();
    clearOpenApiDrafts();
    setStatusMessage("会議を選択しました");
  }

  function selectConversationImport(conversationImport: ConversationImport) {
    setSelectedConversationImport(conversationImport);
    setConversationSummaryDraft(conversationImport.latest_summary_draft ?? null);
    setConversationSummaryReview(null);
    setConversationSafetyFlags(conversationImport.safety_flags);
    setConversationRedactionSuggestions([]);
    setConversationTitle(conversationImport.title);
    setConversationParticipants(linesToText(conversationImport.participants.map((participant) => participant.display_name)));
    setConversationRawText(conversationImport.raw_text);
    setConversationRedactedText(conversationImport.redacted_text ?? "");
    setConversationConsentConfirmed(conversationImport.consent_confirmed);
    setStatusMessage("DMインポートを選択しました");
  }

  function resetConversationImportDraft() {
    setSelectedConversationImport(null);
    setConversationSummaryDraft(null);
    setConversationSummaryReview(null);
    setConversationSafetyFlags([]);
    setConversationRedactionSuggestions([]);
    setConversationTitle("Discord DM仕様相談");
    setConversationParticipants("依頼者, PM");
    setConversationRawText(defaultDmText);
    setConversationRedactedText("");
    setConversationConsentConfirmed(false);
    setConversationApprovalNote("同意確認とマスキング内容をレビューしました。");
    setStatusMessage("DM入力を初期化しました");
  }

  function applyConversationImport(nextConversationImport: ConversationImport) {
    setSelectedConversationImport(nextConversationImport);
    setConversationSummaryDraft(nextConversationImport.latest_summary_draft ?? null);
    setConversationSummaryReview(null);
    setConversationImports((current) => [nextConversationImport, ...current.filter((item) => item.id !== nextConversationImport.id)]);
    setConversationTitle(nextConversationImport.title);
    setConversationParticipants(linesToText(nextConversationImport.participants.map((participant) => participant.display_name)));
    setConversationRawText(nextConversationImport.raw_text);
    setConversationRedactedText(nextConversationImport.redacted_text ?? "");
    setConversationConsentConfirmed(nextConversationImport.consent_confirmed);
  }

  function applyMinutes(nextMinutes: Minutes) {
    setMinutes(nextMinutes);
    setSummaryDraft(nextMinutes.summary);
    setDecisionsDraft(linesToText(nextMinutes.decisions.map((decision) => decision.text)));
    setQuestionsDraft(linesToText(nextMinutes.open_questions));
    setActionsDraft(linesToText(nextMinutes.action_items.map((action) => action.text)));
  }

  function applyRequirement(nextRequirement: Requirement, options: ApplyRequirementOptions = {}) {
    setRequirement(nextRequirement);
    setRequirementReviews([]);
    setRequirementHistory([]);
    setRequirementBackgroundDraft(nextRequirement.background);
    setRequirementGoalDraft(nextRequirement.goal);
    setUserStoriesDraft(linesToText(nextRequirement.user_stories ?? []));
    setFunctionalRequirementsDraft(linesToText(nextRequirement.functional_requirements));
    setNonFunctionalRequirementsDraft(linesToText(nextRequirement.non_functional_requirements ?? []));
    setAcceptanceCriteriaDraft(linesToText(nextRequirement.acceptance_criteria));
    setOutOfScopeDraft(linesToText(nextRequirement.out_of_scope ?? []));
    setRequirementOpenQuestionsDraft(linesToText(nextRequirement.open_questions ?? []));
    setRisksDraft(linesToText(nextRequirement.risks ?? []));
    setRequirementApprovalNote(nextRequirement.approval_note ?? defaultRequirementApprovalNote);

    if (options.resetDownstream) {
      setIssueDraft(null);
      setOpenApiDraft(null);
      clearIssueDrafts();
      clearOpenApiDrafts();
      return;
    }

    if (options.staleDownstream) {
      setIssueDraft((current) => (current ? { ...current, status: "stale" } : current));
      setOpenApiDraft((current) => (current ? { ...current, status: "stale" } : current));
      setOpenApiValidation(null);
      setOpenApiReview(null);
    }
  }

  function applyIssueDraft(nextIssueDraft: IssueDraft) {
    setIssueDraft(nextIssueDraft);
    setIssueTitleDraft(nextIssueDraft.title);
    setIssueBodyDraft(nextIssueDraft.body);
    setIssueAcceptanceDraft(linesToText(nextIssueDraft.acceptance_criteria));
    setIssueLabelsDraft(linesToText(nextIssueDraft.labels));
    setReconciliationIssueNumber(
      nextIssueDraft.github_reconciliation?.github_issue_number
        ? String(nextIssueDraft.github_reconciliation.github_issue_number)
        : nextIssueDraft.github_issue_number
          ? String(nextIssueDraft.github_issue_number)
          : "",
    );
    setReconciliationIssueUrl(nextIssueDraft.github_reconciliation?.github_issue_url ?? nextIssueDraft.github_issue_url ?? "");
    setReconciliationApprover("");
    setReconciliationRetryReasonTemplate("github_issue_absence_confirmed");
    setReconciliationMatches([]);
    setReconciliationSearchSummary(null);
  }

  function selectReconciliationMatch(match: GitHubReconciliationMatch) {
    setReconciliationIssueNumber(String(match.github_issue_number));
    setReconciliationIssueUrl(match.github_issue_url);
    setReconciliationNote((current) => current || `マーカー検索候補 #${match.github_issue_number} を選択しました。`);
    setStatusMessage(`GitHub Issue #${match.github_issue_number} を候補として選択しました`);
  }

  function applyOpenApiDraft(nextOpenApiDraft: OpenApiDraft) {
    setOpenApiDraft(nextOpenApiDraft);
    setOpenApiTitleDraft(nextOpenApiDraft.title);
    setOpenApiContentDraft(nextOpenApiDraft.content);
  }

  function clearMinutesDrafts() {
    setSummaryDraft("");
    setDecisionsDraft("");
    setQuestionsDraft("");
    setActionsDraft("");
  }

  function clearRequirementDrafts() {
    setRequirementBackgroundDraft("");
    setRequirementGoalDraft("");
    setUserStoriesDraft("");
    setFunctionalRequirementsDraft("");
    setNonFunctionalRequirementsDraft("");
    setAcceptanceCriteriaDraft("");
    setOutOfScopeDraft("");
    setRequirementOpenQuestionsDraft("");
    setRisksDraft("");
    setRequirementApprovalNote(defaultRequirementApprovalNote);
    setRequirementReviews([]);
    setRequirementHistory([]);
  }

  function clearIssueDrafts() {
    setIssueTitleDraft("");
    setIssueBodyDraft("");
    setIssueAcceptanceDraft("");
    setIssueLabelsDraft("");
    setReconciliationIssueNumber("");
    setReconciliationIssueUrl("");
    setReconciliationNote("");
    setReconciliationApprover("");
    setReconciliationRetryReasonTemplate("github_issue_absence_confirmed");
    setReconciliationMatches([]);
  }

  function clearOpenApiDrafts() {
    setOpenApiTitleDraft("");
    setOpenApiContentDraft("");
    setOpenApiValidation(null);
    setOpenApiReview(null);
  }

  const isIssueDraftStale = issueDraft?.status === "stale";
  const isOpenApiDraftStale = openApiDraft?.status === "stale";
  const canPublishIssueDraft =
    !isIssueDraftStale &&
    !isOpenApiDraftStale &&
    issueDraft?.status === "approved" &&
    (openApiDraft?.status === "valid" || openApiDraft?.status === "approved") &&
    openApiReview?.status !== "action_required";
  const canGenerateConversationSummary = selectedConversationImport?.status === "ready_for_ai";
  const canEditConversationSummaryDraft = Boolean(
    conversationSummaryDraft && editableConversationSummaryStatus(conversationSummaryDraft.status)
  );
  const hasBlockingConversationSummaryReview = blockingReviewStatus(conversationSummaryReview?.status);
  const latestRequirementReview = requirementReviews[0] ?? null;
  const requirementReviewToResolve = requirementReviews.find((review) => blockingReviewStatus(review.status)) ?? null;
  const unresolvedRequirementReviews = requirementReviews.filter((review) => blockingReviewStatus(review.status));
  const expiredRequirementRiskReviews = requirementReviews.filter(acceptedRiskExpired);
  const requirementOpenQuestions = requirement?.open_questions ?? [];
  const requirementRisks = requirement?.risks ?? [];
  const requirementOpenQuestionCount = requirementOpenQuestions.length;
  const requirementRiskCount = requirementRisks.length;
  const requirementApprovalNoteMissing = Boolean(requirement) && !requirementApprovalNote.trim();
  const requirementApprovalDetailBlockers: RequirementApprovalBlocker[] = requirement
    ? [
        ...unresolvedRequirementReviews.map((review) => ({
          key: `review-${review.id}`,
          title: "未解決レビュー",
          status: `${statusLabel(review.status)} / ${review.reviewer_role}`,
          detail: review.next_actions[0] ?? "レビュー対応が必要です。",
        })),
        ...expiredRequirementRiskReviews.map((review) => ({
          key: `accepted-risk-${review.id}`,
          title: "期限切れリスク受容",
          status: `期限 ${formatDateTime(acceptedRiskExpiresAt(review))}`,
          detail: "リスク受容の期限を更新するか、レビューを解決してください。",
        })),
        ...(requirementApprovalNoteMissing
          ? [
              {
                key: "approval-note",
                title: "承認コメント",
                status: "未入力",
                detail: "承認判断の理由を監査できるようにコメントを入力してください。",
              },
            ]
          : []),
      ]
    : [];
  const hasRequirementApprovalBlockers =
    Boolean(requirement) && (requirementOpenQuestionCount > 0 || requirementApprovalDetailBlockers.length > 0);
  const latestRequirementChange = requirementHistory.find(
    (item) => (item.changed_fields?.length ?? 0) > 0 || (item.changes?.length ?? 0) > 0 || Boolean(item.stale_issue_draft_count || item.stale_open_api_draft_count)
  );
  const latestRequirementChangeCount = latestRequirementChange?.changed_fields?.length ?? latestRequirementChange?.changes?.length ?? 0;
  const latestRequirementChangeLabels =
    latestRequirementChange?.changed_fields?.map(requirementFieldLabel).join("、") ??
    latestRequirementChange?.changes?.map((change) => requirementFieldLabel(change.field)).join("、") ??
    "";
  const hasStaleDownstreamDrafts = isIssueDraftStale || isOpenApiDraftStale;
  const requirementDecisionSummaryItems: RequirementDecisionSummaryItem[] = requirement
    ? [
        {
          key: "open-questions",
          title: "未決事項",
          value: `${requirementOpenQuestionCount}件`,
          detail: requirementOpenQuestionCount > 0 ? trimSummaryText(requirementOpenQuestions[0]) : "未決事項はありません。",
          action: requirementOpenQuestionCount > 0 ? "回答または削除が必要" : "承認確認へ進めます",
          tone: requirementOpenQuestionCount > 0 ? "danger" : "success",
        },
        {
          key: "risks",
          title: "リスク",
          value: `${requirementRiskCount}件`,
          detail: requirementRiskCount > 0 ? trimSummaryText(requirementRisks[0]) : "登録済みリスクはありません。",
          action: requirementRiskCount > 0 ? "対策または受容を確認" : "追加確認なし",
          tone: requirementRiskCount > 0 ? "warning" : "success",
        },
        {
          key: "reviews",
          title: "レビュー",
          value: unresolvedRequirementReviews.length > 0 ? `${unresolvedRequirementReviews.length}件未解決` : latestRequirementReview ? statusLabel(latestRequirementReview.status) : "未依頼",
          detail: latestRequirementReview
            ? `${latestRequirementReview.reviewer_role} / ${statusLabel(latestRequirementReview.status)}`
            : "レビュー依頼後に状態が表示されます。",
          action: unresolvedRequirementReviews.length > 0 ? "レビュー対応が必要" : "ブロッカーなし",
          tone: unresolvedRequirementReviews.length > 0 ? "danger" : latestRequirementReview ? "success" : "neutral",
        },
        {
          key: "latest-change",
          title: "最新差分",
          value: latestRequirementChange ? `${latestRequirementChangeCount || 1}項目` : "なし",
          detail: latestRequirementChange
            ? latestRequirementChangeLabels || latestRequirementChange.title || "下流Draftの再確認が必要です。"
            : "保存後に変更履歴が表示されます。",
          action: latestRequirementChange?.approval_reset ? "再承認が必要" : latestRequirementChange ? "履歴で確認" : "差分なし",
          tone: latestRequirementChange?.approval_reset || hasStaleDownstreamDrafts ? "warning" : latestRequirementChange ? "review" : "neutral",
        },
        {
          key: "downstream",
          title: "下流Draft",
          value: hasStaleDownstreamDrafts ? "再確認が必要" : requirement.status === "approved" ? "生成可能" : "承認待ち",
          detail: hasStaleDownstreamDrafts
            ? "IssueまたはOpenAPIドラフトが古くなっています。"
            : requirement.status === "approved"
              ? "IssueとOpenAPIを生成できます。"
              : "要件承認後に下流生成へ進めます。",
          action: hasStaleDownstreamDrafts ? "再承認と再生成を確認" : "状態確認済み",
          tone: hasStaleDownstreamDrafts ? "warning" : requirement.status === "approved" ? "success" : "neutral",
        },
      ]
    : [];
  const requirementAttentionItems: RequirementAttentionItem[] = requirement
    ? [
        ...requirementOpenQuestions.slice(0, 3).map((question, index) => ({
          key: `open-question-${index}`,
          label: `未決事項 ${index + 1}`,
          body: trimSummaryText(question),
          meta: "承認前に回答、削除、またはレビュー依頼が必要です。",
          tone: "danger" as RequirementFocusTone,
        })),
        ...requirementRisks.slice(0, 3).map((risk, index) => ({
          key: `risk-${index}`,
          label: `リスク ${index + 1}`,
          body: trimSummaryText(risk),
          meta: "対策、受容期限、残存リスクを確認します。",
          tone: "warning" as RequirementFocusTone,
        })),
        ...(latestRequirementChange?.changes?.slice(0, 4).map((change) => ({
          key: `change-${latestRequirementChange.id}-${change.field}`,
          label: requirementFieldLabel(change.field),
          body: requirementHistoryChangeLabel(change),
          meta: latestRequirementChange.approval_reset ? "承認済み要件の再編集により再承認が必要です。" : "最新差分です。",
          tone: latestRequirementChange.approval_reset ? ("warning" as RequirementFocusTone) : ("review" as RequirementFocusTone),
        })) ?? []),
      ]
    : [];
  const canApproveConversationSummaryDraft = Boolean(
    conversationSummaryDraft && conversationSummaryDraft.status === "draft" && !hasBlockingConversationSummaryReview
  );
  const hasPendingGitHubReconciliation = issueDraft?.github_reconciliation?.pending === true;
  const isGitHubReconciliationCooldownActive =
    hasPendingGitHubReconciliation &&
    (issueDraft?.github_reconciliation?.reconciliation_cooldown_active === true ||
      isFutureDateTime(issueDraft?.github_reconciliation?.next_reconciliation_retry_at));
  const githubConnectionStatus = githubIntegration?.status ?? "not_connected";
  const githubConnectionActionLabel = githubConnectionStatus === "connected" ? "GitHub接続をやり直す" : "GitHub連携を開始";
  const queueHealthStatus = queueHealth?.status ?? "unavailable";
  const staleWorkerCount = queueHealth?.workers.filter((worker) => worker.stale).length ?? 0;
  const failedExecutionCount = queueHealth?.failed_executions.count ?? 0;
  const recentProductFailedCount = queueHealth?.product_jobs.recent_failed_count ?? 0;
  const queueRows = queueHealth?.queues.slice(0, 4) ?? [];
  const failedJobRows = queueHealth?.failed_job_samples.slice(0, 3) ?? [];
  const failedJobOperationMetrics = queueHealth?.failed_job_operation_metrics;
  const failedJobOperationHistoryRows = queueHealth?.failed_job_operation_history.slice(0, 3) ?? [];
  const failedJobReleaseGate = queueHealth?.failed_job_release_gate;
  const failedJobReleaseGateChecks = failedJobReleaseGate?.checks.slice(0, 4) ?? [];
  const warningRows = queueHealth?.warnings.slice(0, 3) ?? [];
  const bearerAuthAvailable = clientReady && hasBearerAuth();
  const currentAuthSession = authSessions.find((authSession) => authSession.current) ?? null;
  const otherAuthSessions = authSessions.filter((authSession) => !authSession.current);

  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="主要ナビゲーション">
        <div className="brand">
          <span className="brand-mark">AP</span>
          <span>AI PM</span>
        </div>
        <nav className="nav-list">
          <a className="nav-item active" href="#meeting">
            <ClipboardList size={16} />
            会議
          </a>
          <a className="nav-item" href="#minutes">
            <FileCheck2 size={16} />
            議事録
          </a>
          <a className="nav-item" href="#conversation-import">
            <MessageSquareText size={16} />
            DM整理
          </a>
          <a className="nav-item" href="#memberships">
            <ShieldCheck size={16} />
            メンバー
          </a>
          <a className="nav-item" href="#requirements">
            <ListChecks size={16} />
            要件定義
          </a>
          <a className="nav-item" href="#issue-draft">
            <ClipboardList size={16} />
            Issueドラフト
          </a>
          <a className="nav-item" href="#openapi-draft">
            <FileCode2 size={16} />
            OpenAPIドラフト
          </a>
          <a className="nav-item" href="#operations">
            <Activity size={16} />
            運用
          </a>
          <a className="nav-item" href="#review">
            <CheckCircle2 size={16} />
            レビュー
          </a>
        </nav>
      </aside>

      <main className="workspace">
        <header className="top-bar">
          <div>
            <p className="eyebrow">プロジェクト</p>
            <h1>{selectedProject?.name ?? "AI議事録プラットフォーム"}</h1>
          </div>
          <div className="top-status">
            <span className={`chip ${error ? "danger" : "success"}`}>{error ? "APIエラー" : statusMessage}</span>
            {lastJob ? <span className={`chip ${statusTone(lastJob.status)}`}>ジョブ {statusLabel(lastJob.status)}</span> : null}
            <button className="icon-button" type="button" onClick={loadProjects} aria-label="プロジェクトを再読み込み">
              <RefreshCw size={16} />
            </button>
          </div>
        </header>

        <div className="main-grid">
          <section className="context-bar">
            <div>
              <p className="eyebrow">会議ワークスペース</p>
              <h2>Discordログから議事録を生成</h2>
            </div>
            <div className="action-row">
              <button className="button secondary" type="button" onClick={saveMinutes} disabled={!minutes || loading}>
                <Save size={16} />
                議事録保存
              </button>
              <button className="button secondary" type="button" onClick={saveRequirement} disabled={!requirement || loading}>
                <Save size={16} />
                要件保存
              </button>
              <button className="button secondary" type="button" onClick={saveIssueDraft} disabled={!issueDraft || loading}>
                <Save size={16} />
                Issue保存
              </button>
              <button className="button secondary" type="button" onClick={approveIssueDraft} disabled={!issueDraft || loading}>
                <CheckCircle2 size={16} />
                Issue承認
              </button>
              <button className="button secondary" type="button" onClick={saveConversationImport} disabled={!selectedProjectId || loading}>
                <Save size={16} />
                DM保存
              </button>
              <button className="button secondary" type="button" onClick={scanConversationImport} disabled={!selectedConversationImport || loading}>
                <CheckCircle2 size={16} />
                DMスキャン
              </button>
              <button className="button primary" type="button" onClick={publishIssueDraft} disabled={!canPublishIssueDraft || loading}>
                <Send size={16} />
                GitHub公開
              </button>
              <button className="button secondary" type="button" onClick={saveOpenApiDraft} disabled={!openApiDraft || loading}>
                <Save size={16} />
                API保存
              </button>
              <button className="button secondary" type="button" onClick={validateOpenApiDraft} disabled={!openApiDraft || loading}>
                <CheckCircle2 size={16} />
                API検証
              </button>
              <button className="button primary" type="button" onClick={generateMinutes} disabled={!selectedMeeting || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <Play size={16} />}
                議事録生成
              </button>
              <button className="button primary" type="button" onClick={generateRequirement} disabled={!minutes || minutes.status !== "approved" || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <ListChecks size={16} />}
                要件生成
              </button>
              <button className="button primary" type="button" onClick={generateIssueDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <ClipboardList size={16} />}
                Issue生成
              </button>
              <button className="button primary" type="button" onClick={generateOpenApiDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <FileCode2 size={16} />}
                OpenAPI生成
              </button>
              <button className="button primary" type="button" onClick={generateConversationSummary} disabled={!canGenerateConversationSummary || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <MessageSquareText size={16} />}
                DM整理生成
              </button>
            </div>
          </section>

          {error && !authLocked ? (
            <section className="alert danger" role="alert">
              <AlertTriangle size={18} />
              <span>{error}</span>
            </section>
          ) : null}

          {authLocked ? (
            <section className="auth-lock-panel" role="alert" aria-live="assertive" aria-label="再ログインが必要です">
              <div className="auth-lock-copy">
                <AlertTriangle size={22} />
                <div>
                  <p className="eyebrow">ログインセッション</p>
                  <h2 ref={authLockHeadingRef} tabIndex={-1}>
                    再ログインが必要です
                  </h2>
                  <p>{authLockMessage}</p>
                </div>
              </div>
              <div className="auth-lock-actions">
                {authLockCode ? <span className="chip danger">{authLockCode}</span> : null}
                <button className="button primary" type="button" onClick={retryAuth}>
                  <RefreshCw size={16} />
                  再ログイン
                </button>
              </div>
            </section>
          ) : (
            <>
          <section className="workspace-grid">
            <div className="left-rail">
              <section className="tool-panel">
                <div className="panel-header">
                  <h3>プロジェクト</h3>
                  <span className="chip neutral">{projects.length}</span>
                </div>
                <label>
                  名称
                  <input value={projectName} onChange={(event) => setProjectName(event.target.value)} />
                </label>
                <label>
                  GitHubリポジトリ
                  <input value={projectRepo} onChange={(event) => setProjectRepo(event.target.value)} />
                </label>
                <button className="button full-width" type="button" onClick={createProject} disabled={loading}>
                  <Plus size={16} />
                  プロジェクト作成
                </button>
                <select value={selectedProjectId} onChange={(event) => setSelectedProjectId(event.target.value)}>
                  <option value="">プロジェクト未選択</option>
                  {projects.map((project) => (
                    <option key={project.id} value={project.id}>
                      {project.name}
                    </option>
                  ))}
                </select>
              </section>

              <section className="tool-panel" id="auth-sessions" aria-label="ログインセッション">
                <div className="panel-header">
                  <h3>ログインセッション</h3>
                  <span className={`chip ${bearerAuthAvailable ? "success" : "neutral"}`}>
                    {bearerAuthAvailable ? `${authSessionMeta?.active_count ?? 0}件有効` : "未接続"}
                  </span>
                </div>
                {bearerAuthAvailable ? (
                  <>
                    <div className="session-summary">
                      <strong>この端末</strong>
                      <span>{currentAuthSession ? statusLabel(currentAuthSession.status) : "-"}</span>
                      <strong>期限</strong>
                      <span>{formatDateTime(currentAuthSession?.expires_at)}</span>
                      <strong>他の端末</strong>
                      <span>{otherAuthSessions.length}件</span>
                    </div>
                    <div className="session-actions">
                      <button className="button secondary full-width" type="button" onClick={loadAuthSessions} disabled={loading}>
                        <RefreshCw size={16} />
                        セッション更新
                      </button>
                      <button className="button secondary full-width" type="button" onClick={logoutCurrentSession} disabled={loading || !currentAuthSession}>
                        <UserMinus size={16} />
                        この端末からログアウト
                      </button>
                      <button className="button full-width" type="button" onClick={logoutEverywhere} disabled={loading || !currentAuthSession}>
                        <AlertTriangle size={16} />
                        すべての端末からログアウト
                      </button>
                    </div>
                    <div className="session-list" aria-label="ログインセッション一覧">
                      {authSessions.map((authSession) => (
                        <div className="session-row" key={authSession.id}>
                          <div>
                            <strong>{authSession.current ? "この端末" : "他の端末"}</strong>
                            <span className={`chip ${statusTone(authSession.status)}`}>{statusLabel(authSession.status)}</span>
                          </div>
                          <span>期限 {formatDateTime(authSession.expires_at)}</span>
                          {authSession.revoked_at ? <span>失効 {formatDateTime(authSession.revoked_at)}</span> : null}
                          {!authSession.current && authSession.status === "active" ? (
                            <button className="button secondary full-width" type="button" onClick={() => revokeAuthSession(authSession)} disabled={loading}>
                              <UserMinus size={16} />
                              このセッションを失効
                            </button>
                          ) : null}
                        </div>
                      ))}
                      {authSessions.length === 0 ? <p className="empty">ログインセッションはまだ取得できません。</p> : null}
                    </div>
                  </>
                ) : (
                  <p className="empty">ログインセッションはまだ取得できません。</p>
                )}
              </section>

              <section className="tool-panel" id="memberships" aria-label="メンバー管理">
                <div className="panel-header">
                  <h3>メンバー管理</h3>
                  <span className="chip neutral">{projectMemberships.length}</span>
                </div>
                <div className="membership-create">
                  <label>
                    メンバーID
                    <input value={newMemberActorId} onChange={(event) => setNewMemberActorId(event.target.value)} />
                  </label>
                  <label>
                    権限
                    <select
                      value={newMemberRole}
                      onChange={(event) => setNewMemberRole(event.target.value as ProjectMembershipRole)}
                    >
                      {projectMembershipRoles.map((role) => (
                        <option key={role} value={role}>
                          {statusLabel(role)}
                        </option>
                      ))}
                    </select>
                  </label>
                  <button className="button full-width" type="button" onClick={createProjectMembership} disabled={loading || !selectedProjectId}>
                    <UserPlus size={16} />
                    メンバー追加
                  </button>
                </div>
                <div className="membership-list" aria-label="プロジェクトメンバー一覧">
                  {projectMemberships.map((membership) => (
                    <div className="membership-row" key={membership.id}>
                      <div>
                        <strong>{membership.actor_id}</strong>
                        <span className={`chip ${statusTone(membership.status)}`}>{statusLabel(membership.status)}</span>
                      </div>
                      <label>
                        権限
                        <select
                          value={membership.role}
                          disabled={loading || membership.status !== "active"}
                          onChange={(event) => updateProjectMembershipRole(membership, event.target.value as ProjectMembershipRole)}
                        >
                          {projectMembershipRoles.map((role) => (
                            <option key={role} value={role}>
                              {statusLabel(role)}
                            </option>
                          ))}
                        </select>
                      </label>
                      <button
                        className="button secondary full-width"
                        type="button"
                        onClick={() => revokeProjectMembership(membership)}
                        disabled={loading || membership.status !== "active"}
                      >
                        <UserMinus size={16} />
                        失効
                      </button>
                    </div>
                  ))}
                  {projectMemberships.length === 0 ? <p className="empty">メンバーはまだ読み込まれていません。</p> : null}
                </div>
              </section>

              <section className="tool-panel" aria-label="GitHub連携">
                <div className="panel-header">
                  <h3>GitHub連携</h3>
                  <span className={`chip ${statusTone(githubConnectionStatus)}`}>{statusLabel(githubConnectionStatus)}</span>
                </div>
                <div className="integration-summary">
                  <strong>リポジトリ</strong>
                  <span>{selectedProject?.github_repo || projectRepo || "-"}</span>
                  <strong>アカウント</strong>
                  <span>{githubIntegration?.github_account_login ?? "-"}</span>
                  <strong>権限</strong>
                  <span>{githubIntegration?.granted_permissions?.issues ? `Issues ${githubIntegration.granted_permissions.issues}` : "-"}</span>
                  <strong>最終同期</strong>
                  <span>{formatDateTime(githubIntegration?.last_sync_at)}</span>
                  {githubIntegration?.last_error_safe ? (
                    <>
                      <strong>エラー</strong>
                      <span>{displayMessage(githubIntegration.last_error_safe)}</span>
                    </>
                  ) : null}
                </div>
                <button className="button full-width" type="button" onClick={startGitHubConnection} disabled={loading || !selectedProjectId}>
                  <GitBranch size={16} />
                  {githubConnectionActionLabel}
                </button>
                {githubInstallationUrl ? (
                  <a className="button primary full-width" href={githubInstallationUrl} target="_blank" rel="noreferrer">
                    <GitBranch size={16} />
                    GitHub App設定を開く
                  </a>
                ) : null}
              </section>

              <section className="tool-panel" id="operations" aria-label="運用監視">
                <div className="panel-header">
                  <h3>運用監視</h3>
                  <span className={`chip ${statusTone(queueHealthStatus)}`}>{statusLabel(queueHealthStatus)}</span>
                </div>
                <div className="operation-summary">
                  <strong>更新</strong>
                  <span>{formatDateTime(queueHealth?.checked_at)}</span>
                  <strong>ワーカー</strong>
                  <span>
                    {queueHealth ? `全${queueHealth.workers.length}件 / 古い応答${staleWorkerCount}件` : "-"}
                  </span>
                  <strong>失敗</strong>
                  <span>{failedExecutionCount}件</span>
                  <strong>アプリジョブ失敗</strong>
                  <span>{recentProductFailedCount}件</span>
                  <strong>定期タスク</strong>
                  <span>{queueHealth ? `${queueHealth.recurring_tasks.length}件` : "-"}</span>
                  <strong>操作</strong>
                  <span>
                    {failedJobOperationMetrics
                      ? `再実行${failedJobOperationMetrics.retry_count}件 / 破棄${failedJobOperationMetrics.discard_count}件 / 拒否${failedJobOperationMetrics.rejected_count}件`
                      : "-"}
                  </span>
                  <strong>リリースゲート</strong>
                  <span>{failedJobReleaseGate ? failedJobReleaseGateStatusLabels[failedJobReleaseGate.status] : "-"}</span>
                  <strong>通知</strong>
                  <span>
                    {failedJobReleaseGate
                      ? `${failedJobReleaseGate.notification_required ? "必要" : "不要"} / ${failedJobReleaseGate.notification_channel}`
                      : "-"}
                  </span>
                </div>
                {failedJobReleaseGate ? (
                  <div className="release-gate-list" aria-label="失敗ジョブリリースゲート">
                    <div className="release-gate-header">
                      <strong className="mini-heading">リリースゲート</strong>
                      <span className={`chip ${statusTone(failedJobReleaseGate.status)}`}>
                        {failedJobReleaseGateStatusLabels[failedJobReleaseGate.status]}
                      </span>
                    </div>
                    <div className="release-gate-policy">
                      <strong>破棄承認</strong>
                      <span>
                        {failedJobReleaseGate.approval_policy.discard.second_approval_required ? "二人承認" : "単独承認"} /{" "}
                        {failedJobReleaseGate.approval_policy.discard.required_role}
                      </span>
                    </div>
                    {failedJobReleaseGateChecks.map((check) => (
                      <div className={`release-gate-row ${statusTone(check.status)}`} key={check.key}>
                        <div>
                          <strong>{check.label}</strong>
                          <span>
                            {failedJobReleaseGateSeverityLabels[check.severity]} / {check.observed_value} / 閾値 {check.threshold}
                          </span>
                        </div>
                        <span className={`chip ${statusTone(check.status)}`}>{failedJobReleaseGateCheckStatusLabels[check.status]}</span>
                        <p>{check.next_action}</p>
                      </div>
                    ))}
                  </div>
                ) : null}
                <div className="queue-list" aria-label="キュー状態一覧">
                  {queueRows.map((queue) => (
                    <div className="queue-row" key={queue.queue_name}>
                      <strong>{queue.queue_name}</strong>
                      <span>
                        {queue.unfinished_count}件 / {queue.oldest_unfinished_age_seconds ? `${queue.oldest_unfinished_age_seconds}秒` : "-"}
                      </span>
                    </div>
                  ))}
                  {queueRows.length === 0 ? <p className="empty">キュー未確認</p> : null}
                </div>
                {failedJobRows.length > 0 ? (
                  <div className="failed-job-list" aria-label="直近失敗ジョブ">
                    <strong className="mini-heading">直近失敗ジョブ</strong>
                    {failedJobRows.map((job) => (
                      <div className="failed-job-row" key={`${job.failed_job_id}-${job.active_job_id ?? job.failed_at}`}>
                        <div>
                          <strong>{job.class_name}</strong>
                          <span>{job.queue_name}</span>
                          {job.product_job_id ? <span>管理ジョブID: {job.product_job_id}</span> : null}
                          {job.project_boundary_status === "verified" ? <span>Project境界確認済み</span> : null}
                          {job.product_job_mapping_source ? (
                            <span>境界根拠: {failedJobMappingSourceLabels[job.product_job_mapping_source]}</span>
                          ) : null}
                          <span>{formatDateTime(job.failed_at)}</span>
                        </div>
                        <div className="failed-job-actions">
                          <label>
                            再実行理由
                            <select
                              value={failedJobRetryReasonTemplate(job)}
                              onChange={(event) => updateFailedJobRetryReasonTemplate(job.failed_job_id, event.target.value as FailedJobRetryReasonTemplate)}
                            >
                              {job.operations.retry_reason_templates.map((reasonTemplate) => (
                                <option key={reasonTemplate} value={reasonTemplate}>
                                  {failedJobOperationReasonLabels[reasonTemplate]}
                                </option>
                              ))}
                            </select>
                          </label>
                          <label>
                            破棄理由
                            <select
                              value={failedJobDiscardReasonTemplate(job)}
                              onChange={(event) => updateFailedJobDiscardReasonTemplate(job.failed_job_id, event.target.value as FailedJobDiscardReasonTemplate)}
                            >
                              {job.operations.discard_reason_templates.map((reasonTemplate) => (
                                <option key={reasonTemplate} value={reasonTemplate}>
                                  {failedJobOperationReasonLabels[reasonTemplate]}
                                </option>
                              ))}
                            </select>
                          </label>
                          <label className="failed-job-confirmation">
                            <input
                              type="checkbox"
                              checked={failedJobDiscardConfirmations[job.failed_job_id] === true}
                              onChange={(event) => updateFailedJobDiscardConfirmation(job.failed_job_id, event.target.checked)}
                            />
                            破棄リスクを確認
                          </label>
                          {(() => {
                            const approval = failedJobDiscardApproval(job);
                            const canRequestApproval = !approval || ["rejected", "expired", "consumed"].includes(approval.status);
                            return (
                              <div className="failed-job-approval">
                                <div className="approval-status-line">
                                  <strong>二人承認</strong>
                                  <span>{approval ? failedJobDiscardApprovalStatusLabels[approval.status] : "未依頼"}</span>
                                </div>
                                {approval ? (
                                  <div className="approval-meta">
                                    <span>申請者: {approval.requested_by_actor_id}</span>
                                    {approval.approved_by_actor_id ? <span>承認者: {approval.approved_by_actor_id}</span> : null}
                                    <span>期限: {formatDateTime(approval.expires_at)}</span>
                                  </div>
                                ) : null}
                                {approval?.status === "pending" ? (
                                  <div className="approval-resolution">
                                    <label>
                                      承認コメント
                                      <textarea
                                        rows={2}
                                        value={failedJobApprovalNotes[approval.id] ?? ""}
                                        onChange={(event) => updateFailedJobApprovalNote(approval.id, event.target.value)}
                                      />
                                    </label>
                                    <label>
                                      却下理由
                                      <textarea
                                        rows={2}
                                        value={failedJobRejectionReasons[approval.id] ?? ""}
                                        onChange={(event) => updateFailedJobRejectionReason(approval.id, event.target.value)}
                                      />
                                    </label>
                                    <div className="failed-job-action-buttons">
                                      <button
                                        className="button secondary"
                                        type="button"
                                        onClick={() => resolveFailedJobDiscardApproval(approval, "approve")}
                                        disabled={failedJobOperationId === job.failed_job_id || queueHealthLoading}
                                      >
                                        <ShieldCheck size={16} />
                                        承認
                                      </button>
                                      <button
                                        className="button secondary"
                                        type="button"
                                        onClick={() => resolveFailedJobDiscardApproval(approval, "reject")}
                                        disabled={failedJobOperationId === job.failed_job_id || queueHealthLoading}
                                      >
                                        <UserMinus size={16} />
                                        却下
                                      </button>
                                    </div>
                                  </div>
                                ) : null}
                                {canRequestApproval ? (
                                  <button
                                    className="button secondary"
                                    type="button"
                                    onClick={() => requestFailedJobDiscardApproval(job)}
                                    disabled={failedJobOperationId === job.failed_job_id || queueHealthLoading || !job.operations.discardable}
                                  >
                                    <ShieldCheck size={16} />
                                    破棄承認を依頼
                                  </button>
                                ) : null}
                              </div>
                            );
                          })()}
                          <div className="failed-job-action-buttons">
                            <button
                              className="button secondary"
                              type="button"
                              onClick={() => operateFailedJob(job, "retry")}
                              disabled={failedJobOperationId === job.failed_job_id || queueHealthLoading || !job.operations.retryable}
                            >
                              {failedJobOperationId === job.failed_job_id ? <Loader2 className="spin" size={16} /> : <Play size={16} />}
                              再実行
                            </button>
                            <button
                              className="button secondary"
                              type="button"
                              onClick={() => operateFailedJob(job, "discard")}
                              disabled={
                                failedJobOperationId === job.failed_job_id ||
                                queueHealthLoading ||
                                !job.operations.discardable ||
                                failedJobDiscardApproval(job)?.status !== "approved"
                              }
                            >
                              {failedJobOperationId === job.failed_job_id ? <Loader2 className="spin" size={16} /> : <Trash2 size={16} />}
                              破棄
                            </button>
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : null}
                {failedJobOperationHistoryRows.length > 0 ? (
                  <div className="failed-job-list" aria-label="失敗ジョブ操作履歴">
                    <strong className="mini-heading">失敗ジョブ操作履歴</strong>
                    {failedJobOperationHistoryRows.map((entry) => (
                      <div className="failed-job-row" key={entry.id}>
                        <div>
                          <strong>{failedJobOperationActionLabels[entry.action]}</strong>
                          <span>{entry.summary}</span>
                          <span>担当: {entry.actor_id}</span>
                          {entry.reason_template ? <span>理由: {failedJobOperationReasonLabels[entry.reason_template]}</span> : null}
                          {entry.project_boundary_status ? <span>境界: {statusLabel(entry.project_boundary_status)}</span> : null}
                          {entry.product_job_mapping_source ? (
                            <span>境界根拠: {failedJobMappingSourceLabels[entry.product_job_mapping_source]}</span>
                          ) : null}
                          <span>{formatDateTime(entry.created_at)}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : null}
                {warningRows.length > 0 ? (
                  <div className="warning-list" aria-label="キュー警告">
                    {warningRows.map((warning) => (
                      <span key={warning}>{displayMessage(warning)}</span>
                    ))}
                  </div>
                ) : null}
                <button className="button secondary full-width" type="button" onClick={() => loadQueueHealth()} disabled={queueHealthLoading}>
                  {queueHealthLoading ? <Loader2 className="spin" size={16} /> : <RefreshCw size={16} />}
                  運用状態更新
                </button>
              </section>

              <section className="tool-panel">
                <div className="panel-header">
                  <h3>会議</h3>
                  <span className="chip neutral">{meetings.length}</span>
                </div>
                <div className="meeting-list">
                  {meetings.map((meeting) => (
                    <button
                      className={meeting.id === selectedMeeting?.id ? "meeting-row active" : "meeting-row"}
                      key={meeting.id}
                      type="button"
                      onClick={() => selectMeeting(meeting)}
                    >
                      <strong>{meeting.title}</strong>
                      <span>{formatDateTime(meeting.created_at)}</span>
                    </button>
                  ))}
                  {meetings.length === 0 ? <p className="empty">会議なし</p> : null}
                </div>
              </section>

              <section className="tool-panel" aria-label="DMインポート一覧">
                <div className="panel-header">
                  <h3>DM整理</h3>
                  <span className="chip neutral">{conversationImports.length}</span>
                </div>
                <div className="meeting-list">
                  {conversationImports.map((conversationImport) => (
                    <button
                      className={conversationImport.id === selectedConversationImport?.id ? "meeting-row active" : "meeting-row"}
                      key={conversationImport.id}
                      type="button"
                      onClick={() => selectConversationImport(conversationImport)}
                    >
                      <strong>{conversationImport.title}</strong>
                      <span>
                        {statusLabel(conversationImport.status)} / {formatDateTime(conversationImport.created_at)}
                      </span>
                    </button>
                  ))}
                  {conversationImports.length === 0 ? <p className="empty">DMインポートなし</p> : null}
                </div>
              </section>
            </div>

            <section className="tool-panel transcript-panel" id="meeting">
              <div className="panel-header">
                <h3>会議ログ</h3>
                <span className={`chip ${selectedMeeting ? "success" : "neutral"}`}>{selectedMeeting ? statusLabel("saved") : statusLabel("draft")}</span>
              </div>
              <div className="form-grid">
                <label>
                  タイトル
                  <input value={meetingTitle} onChange={(event) => setMeetingTitle(event.target.value)} />
                </label>
                <label>
                  日付
                  <input type="date" value={meetingDate} onChange={(event) => setMeetingDate(event.target.value)} />
                </label>
                <label>
                  入力元
                  <select value={sourceType} onChange={(event) => setSourceType(event.target.value as MeetingSourceType)}>
                    <option value="discord_log">Discordログ</option>
                    <option value="manual">手動入力</option>
                    <option value="transcript">文字起こし</option>
                  </select>
                </label>
              </div>
              <label>
                参加者
                <input value={participants} onChange={(event) => setParticipants(event.target.value)} />
              </label>
              <label className="fill">
                原文ログ
                <textarea value={rawText} onChange={(event) => setRawText(event.target.value)} />
              </label>
              <button className="button full-width" type="button" onClick={createMeeting} disabled={loading}>
                <Database size={16} />
                会議を保存
              </button>
            </section>

            <section className="tool-panel minutes-panel" id="minutes">
              <div className="panel-header">
                <h3>議事録エディタ</h3>
                <span className={`chip ${statusTone(minutes?.status)}`}>{statusLabel(minutes?.status)}</span>
              </div>
              <label>
                要約
                <textarea className="summary-editor" value={summaryDraft} onChange={(event) => setSummaryDraft(event.target.value)} />
              </label>
              <div className="editor-columns">
                <label>
                  決定事項
                  <textarea value={decisionsDraft} onChange={(event) => setDecisionsDraft(event.target.value)} />
                </label>
                <label>
                  未解決事項
                  <textarea value={questionsDraft} onChange={(event) => setQuestionsDraft(event.target.value)} />
                </label>
              </div>
              <label className="fill">
                アクション項目
                <textarea value={actionsDraft} onChange={(event) => setActionsDraft(event.target.value)} />
              </label>
            </section>

            <aside className="inspector" id="review">
              <div className="panel-header">
                <h3>レビューゲート</h3>
                <span className={`chip ${minutes?.status === "approved" ? "success" : "danger"}`}>
                  {minutes?.status === "approved" ? statusLabel("clear") : statusLabel("blocked")}
                </span>
              </div>
              <div className="gate-stack">
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>会議保存</span>
                  <strong>{yesNoLabel(Boolean(selectedMeeting))}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>議事録生成</span>
                  <strong>{yesNoLabel(Boolean(minutes))}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>レビュー依頼</span>
                  <strong>{yesNoLabel(Boolean(lastReview))}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>DM整理レビュー</span>
                  <strong>{conversationSummaryReview ? statusLabel(conversationSummaryReview.status) : statusLabel("clear")}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>DM整理承認</span>
                  <strong>{conversationSummaryDraft?.status === "approved" ? statusLabel("approved") : statusLabel("pending")}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>要件定義生成</span>
                  <strong>{yesNoLabel(Boolean(requirement))}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>要件定義承認</span>
                  <strong>{yesNoLabel(requirement?.status === "approved")}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Issueドラフト生成</span>
                  <strong>{yesNoLabel(Boolean(issueDraft))}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Issueドラフト承認</span>
                  <strong>{issueDraft?.status === "approved" || issueDraft?.status === "published" ? statusLabel("approved") : issueDraft?.status === "publish_failed" ? statusLabel("failed") : statusLabel("pending")}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>OpenAPIドラフト生成</span>
                  <strong>{yesNoLabel(Boolean(openApiDraft))}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>OpenAPI検証</span>
                  <strong>{openApiDraft?.status === "valid" || openApiDraft?.status === "approved" ? statusLabel("valid") : openApiDraft?.status === "invalid" ? statusLabel("invalid") : statusLabel("pending")}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>OpenAPIブロッカー</span>
                  <strong>{openApiReview ? statusLabel(openApiReview.status) : statusLabel("clear")}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>GitHub Issue公開</span>
                  <strong>{issueDraft?.github_issue_url ? statusLabel("published") : issueDraft?.status === "publish_failed" ? statusLabel("failed") : statusLabel("pending")}</strong>
                </div>
              </div>
              <button className="button full-width" type="button" onClick={requestMinutesReview} disabled={!minutes || loading}>
                <Send size={16} />
                レビュー依頼
              </button>
              <button className="button primary full-width" type="button" onClick={approveMinutes} disabled={!minutes || loading}>
                <CheckCircle2 size={16} />
                議事録を承認
              </button>
              <div className="audit-box">
                <strong>最新ジョブ</strong>
                <span>{lastJob ? `${statusLabel(lastJob.status)} / ${targetLabel(lastJob.target_type)}` : "-"}</span>
                <strong>モデル</strong>
                <span>{requirement?.generated_by_model ?? minutes?.generated_by_model ?? "-"}</span>
                <strong>レビュー</strong>
                <span>{lastReview ? `${statusLabel(lastReview.status)} / ${lastReview.reviewer_role}` : "-"}</span>
                <strong>APIブロッカー</strong>
                <span>{openApiReview ? `${statusLabel(openApiReview.status)} / ${openApiReview.reviewer_role}` : "-"}</span>
                <strong>DMレビュー</strong>
                <span>{conversationSummaryReview ? `${statusLabel(conversationSummaryReview.status)} / ${conversationSummaryReview.reviewer_role}` : "-"}</span>
              </div>
            </aside>
          </section>

          <section className="tool-panel conversation-import-panel" id="conversation-import">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Discord DM整理</p>
                <h3>手動インポート</h3>
              </div>
              <span className={`chip ${statusTone(selectedConversationImport?.status)}`}>{statusLabel(selectedConversationImport?.status)}</span>
            </div>
            <div className="requirement-actions">
              <button className="button secondary" type="button" onClick={resetConversationImportDraft} disabled={loading}>
                <Plus size={16} />
                新規入力
              </button>
              <button className="button primary" type="button" onClick={saveConversationImport} disabled={!selectedProjectId || loading}>
                <Save size={16} />
                DMインポートを保存
              </button>
              <button className="button secondary" type="button" onClick={scanConversationImport} disabled={!selectedConversationImport || loading}>
                <CheckCircle2 size={16} />
                安全チェック
              </button>
              <button className="button primary" type="button" onClick={generateConversationSummary} disabled={!canGenerateConversationSummary || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <MessageSquareText size={16} />}
                整理ドラフト生成
              </button>
              <button
                className="button secondary"
                type="button"
                onClick={saveConversationSummaryDraftEdits}
                disabled={!canEditConversationSummaryDraft || loading}
              >
                <Save size={16} />
                整理ドラフト保存
              </button>
              <button
                className="button secondary"
                type="button"
                onClick={requestConversationSummaryReview}
                disabled={!conversationSummaryDraft || loading}
              >
                <Send size={16} />
                DM整理レビュー依頼
              </button>
              <button
                className="button secondary"
                type="button"
                onClick={resolveConversationSummaryReview}
                disabled={!hasBlockingConversationSummaryReview || loading}
              >
                <CheckCircle2 size={16} />
                レビュー対応済み
              </button>
              <button className="button primary" type="button" onClick={approveConversationSummary} disabled={!canApproveConversationSummaryDraft || loading}>
                <CheckCircle2 size={16} />
                整理ドラフト承認
              </button>
              <button
                className="button secondary"
                type="button"
                onClick={anonymizeConversationImport}
                disabled={!selectedConversationImport || Boolean(selectedConversationImport.anonymized_at) || loading}
              >
                <Trash2 size={16} />
                DM匿名化
              </button>
            </div>
            <div className="conversation-editor-grid">
              <label>
                DMタイトル
                <input value={conversationTitle} onChange={(event) => setConversationTitle(event.target.value)} />
              </label>
              <label>
                参加者
                <input value={conversationParticipants} onChange={(event) => setConversationParticipants(event.target.value)} />
              </label>
              <label className="checkbox-row">
                <input
                  type="checkbox"
                  checked={conversationConsentConfirmed}
                  onChange={(event) => setConversationConsentConfirmed(event.target.checked)}
                />
                <span>取り込み権限と相手方同意を確認済み</span>
              </label>
              <label className="conversation-wide">
                DM原文
                <textarea value={conversationRawText} onChange={(event) => setConversationRawText(event.target.value)} />
              </label>
              <label className="conversation-wide">
                マスキング後テキスト
                <textarea value={conversationRedactedText} onChange={(event) => setConversationRedactedText(event.target.value)} />
              </label>
            </div>
            {selectedConversationImport ? (
              <div className="audit-box conversation-audit">
                <strong>保存状態</strong>
                <span>{statusLabel(selectedConversationImport.status)}</span>
                <strong>同意</strong>
                <span>{yesNoLabel(selectedConversationImport.consent_confirmed)}</span>
                <strong>保存日時</strong>
                <span>{formatDateTime(selectedConversationImport.created_at)}</span>
                <strong>原文期限</strong>
                <span>{formatDateTime(selectedConversationImport.raw_text_retention_expires_at)}</span>
                <strong>本文期限</strong>
                <span>{formatDateTime(selectedConversationImport.retention_expires_at)}</span>
                <strong>原文削除</strong>
                <span>{formatDateTime(selectedConversationImport.raw_text_purged_at)}</span>
                <strong>匿名化</strong>
                <span>{formatDateTime(selectedConversationImport.anonymized_at)}</span>
                <strong>同意文言</strong>
                <span>{selectedConversationImport.consent_statement_version}</span>
              </div>
            ) : null}
            {conversationSafetyFlags.length > 0 || conversationRedactionSuggestions.length > 0 ? (
              <div className={`validation-panel ${selectedConversationImport?.status === "blocked" ? "danger" : "warning"}`}>
                <div className="panel-header">
                  <h3>安全チェック結果</h3>
                  <span className={`chip ${selectedConversationImport?.status === "blocked" ? "danger" : "warning"}`}>
                    指摘{conversationSafetyFlags.length}件
                  </span>
                </div>
                {conversationSafetyFlags.length > 0 ? (
                  <div className="validation-list">
                    {conversationSafetyFlags.map((flag, index) => (
                      <div className="validation-row warning" key={`${flag.type}-${flag.location_hint ?? index}`}>
                        <strong>{safetyFlagTypeLabel(flag.type)}</strong>
                        <span>{statusLabel(flag.action)}</span>
                        <p>{flag.message ?? flag.location_hint ?? "確認が必要です。"}</p>
                      </div>
                    ))}
                  </div>
                ) : null}
                {conversationRedactionSuggestions.length > 0 ? (
                  <div className="validation-list">
                    {conversationRedactionSuggestions.map((suggestion, index) => (
                      <div className="validation-row warning" key={`${suggestion.location_hint}-${index}`}>
                        <strong>{suggestion.location_hint}</strong>
                        <span>{suggestion.suggested_replacement}</span>
                        <p>{suggestion.reason}</p>
                      </div>
                    ))}
                  </div>
                ) : null}
              </div>
            ) : null}
            {conversationSummaryDraft ? (
              <div className="validation-panel success" aria-label="DM整理ドラフト">
                <div className="panel-header">
                  <h3>整理ドラフト</h3>
                  <span className={`chip ${statusTone(conversationSummaryDraft.status)}`}>{statusLabel(conversationSummaryDraft.status)}</span>
                  <span className="chip neutral">信頼度 {summaryConfidence(conversationSummaryDraft.confidence)}</span>
                  <span className="chip neutral">{canEditConversationSummaryDraft ? "編集可能" : "読み取り専用"}</span>
                </div>
                <div className="audit-box conversation-audit" aria-label="DM整理レビュー状態">
                  <strong>レビューセンター</strong>
                  <span>{conversationSummaryReview ? statusLabel(conversationSummaryReview.status) : statusLabel("clear")}</span>
                  <strong>対象</strong>
                  <span>{targetLabel("conversation_summary_draft")}</span>
                  <strong>担当</strong>
                  <span>{conversationSummaryReview?.reviewer_role ?? "-"}</span>
                  <strong>承認ブロッカー</strong>
                  <span>{hasBlockingConversationSummaryReview ? statusLabel("blocked") : statusLabel("clear")}</span>
                </div>
                <div className="conversation-summary-grid">
                  <label className="conversation-wide">
                    整理要約
                    <textarea
                      readOnly={!canEditConversationSummaryDraft}
                      value={conversationSummaryDraftEdit.summary}
                      onChange={(event) => setConversationSummaryDraftEdit((current) => ({ ...current, summary: event.target.value }))}
                    />
                  </label>
                  <label>
                    決定事項
                    <textarea
                      readOnly={!canEditConversationSummaryDraft}
                      value={conversationSummaryDraftEdit.decisions}
                      onChange={(event) => setConversationSummaryDraftEdit((current) => ({ ...current, decisions: event.target.value }))}
                    />
                  </label>
                  <label>
                    未解決事項
                    <textarea
                      readOnly={!canEditConversationSummaryDraft}
                      value={conversationSummaryDraftEdit.openQuestions}
                      onChange={(event) => setConversationSummaryDraftEdit((current) => ({ ...current, openQuestions: event.target.value }))}
                    />
                  </label>
                  <label>
                    アクション項目
                    <textarea
                      readOnly={!canEditConversationSummaryDraft}
                      value={conversationSummaryDraftEdit.actionItems}
                      onChange={(event) => setConversationSummaryDraftEdit((current) => ({ ...current, actionItems: event.target.value }))}
                    />
                  </label>
                  <label>
                    リスク
                    <textarea
                      readOnly={!canEditConversationSummaryDraft}
                      value={conversationSummaryDraftEdit.risks}
                      onChange={(event) => setConversationSummaryDraftEdit((current) => ({ ...current, risks: event.target.value }))}
                    />
                  </label>
                </div>
                <div className="conversation-candidates" aria-label="DM由来候補">
                  <label>
                    Issue候補
                    <textarea
                      readOnly={!canEditConversationSummaryDraft}
                      value={conversationSummaryDraftEdit.issueCandidates}
                      onChange={(event) => setConversationSummaryDraftEdit((current) => ({ ...current, issueCandidates: event.target.value }))}
                    />
                  </label>
                  <label>
                    要件候補
                    <textarea
                      readOnly={!canEditConversationSummaryDraft}
                      value={conversationSummaryDraftEdit.requirementCandidates}
                      onChange={(event) =>
                        setConversationSummaryDraftEdit((current) => ({ ...current, requirementCandidates: event.target.value }))
                      }
                    />
                  </label>
                </div>
                <label>
                  承認理由
                  <input value={conversationApprovalNote} onChange={(event) => setConversationApprovalNote(event.target.value)} />
                </label>
              </div>
            ) : null}
          </section>

          <section className="tool-panel requirement-panel" id="requirements">
            <div className="panel-header">
              <div>
                <p className="eyebrow">要件定義ワークスペース</p>
                <h3>要件定義ドラフト</h3>
              </div>
              <span className={`chip ${statusTone(requirement?.status)}`}>{statusLabel(requirement?.status)}</span>
            </div>
            <div className="requirement-actions">
              <button className="button primary" type="button" onClick={generateRequirement} disabled={!minutes || minutes.status !== "approved" || loading}>
                <ListChecks size={16} />
                要件定義を生成
              </button>
              <button className="button secondary" type="button" onClick={saveRequirement} disabled={!requirement || loading}>
                <Save size={16} />
                要件定義を保存
              </button>
              <button className="button primary" type="button" onClick={approveRequirement} disabled={!requirement || hasRequirementApprovalBlockers || loading}>
                <CheckCircle2 size={16} />
                要件定義を承認
              </button>
              <button className="button" type="button" onClick={requestRequirementReview} disabled={!requirement || loading}>
                <Send size={16} />
                要件レビュー依頼
              </button>
              <button
                className="button secondary"
                type="button"
                onClick={resolveRequirementReview}
                disabled={!requirement || !requirementReviewToResolve || loading}
              >
                <CheckCircle2 size={16} />
                要件レビュー対応済み
              </button>
            </div>
            {requirement ? (
              <div className="requirement-decision-summary" aria-label="要件判断サマリー">
                {requirementDecisionSummaryItems.map((item) => (
                  <div className={`requirement-metric-card ${item.tone}`} key={item.key}>
                    <div className="metric-heading">
                      <strong>{item.title}</strong>
                      <span>{item.action}</span>
                    </div>
                    <span className="metric-value">{item.value}</span>
                    <p>{item.detail}</p>
                  </div>
                ))}
              </div>
            ) : null}
            {requirement ? (
              <div className="requirement-focus-grid" aria-label="要件注目ポイント">
                <div className="focus-panel">
                  <div className="panel-header">
                    <h3>未決事項・リスク</h3>
                    <span className={`chip ${requirementOpenQuestionCount + requirementRiskCount > 0 ? "warning" : "success"}`}>
                      {requirementOpenQuestionCount + requirementRiskCount}件
                    </span>
                  </div>
                  <div className="focus-list">
                    {requirementAttentionItems.filter((item) => item.key.startsWith("open-question") || item.key.startsWith("risk")).length ? (
                      requirementAttentionItems
                        .filter((item) => item.key.startsWith("open-question") || item.key.startsWith("risk"))
                        .map((item) => (
                          <div className="focus-item" key={item.key}>
                            <span className={`focus-marker ${item.tone}`}>{item.tone === "danger" ? <AlertTriangle size={14} /> : <Activity size={14} />}</span>
                            <div>
                              <strong>{item.label}</strong>
                              <p>{item.body}</p>
                              <span>{item.meta}</span>
                            </div>
                          </div>
                        ))
                    ) : (
                      <p className="empty">未決事項とリスクはありません。</p>
                    )}
                  </div>
                </div>
                <div className="focus-panel">
                  <div className="panel-header">
                    <h3>差分注目ポイント</h3>
                    <span className={`chip ${latestRequirementChange ? "review" : "neutral"}`}>{latestRequirementChange ? `${latestRequirementChangeCount || 1}項目` : "差分なし"}</span>
                  </div>
                  <div className="focus-list">
                    {requirementAttentionItems.filter((item) => item.key.startsWith("change")).length ? (
                      requirementAttentionItems
                        .filter((item) => item.key.startsWith("change"))
                        .map((item) => (
                          <div className="focus-item" key={item.key}>
                            <span className={`focus-marker ${item.tone}`}>
                              {item.tone === "warning" ? <AlertTriangle size={14} /> : <GitBranch size={14} />}
                            </span>
                            <div>
                              <strong>{item.label}</strong>
                              <p>{item.body}</p>
                              <span>{item.meta}</span>
                            </div>
                          </div>
                        ))
                    ) : (
                      <p className="empty">保存後の差分はまだありません。</p>
                    )}
                  </div>
                </div>
              </div>
            ) : null}
            {requirement ? (
              <div className={`validation-panel ${hasRequirementApprovalBlockers ? "danger" : "success"}`} aria-label="要件承認ブロッカー">
                <h3>承認ブロッカー</h3>
                <div className={`validation-row ${requirementOpenQuestionCount > 0 ? "warning" : "success"}`}>
                  <strong>未決事項</strong>
                  <span>{requirementOpenQuestionCount}件</span>
                  <p>未解決の確認事項が承認前に残っていないかを確認します。</p>
                </div>
                <div className={`validation-row ${unresolvedRequirementReviews.length > 0 ? "warning" : "success"}`}>
                  <strong>未解決レビュー</strong>
                  <span>{unresolvedRequirementReviews.length}件</span>
                  <p>レビューセンターで未対応または追加対応が必要な指摘を確認します。</p>
                </div>
                <div className={`validation-row ${expiredRequirementRiskReviews.length > 0 ? "warning" : "success"}`}>
                  <strong>期限切れリスク受容</strong>
                  <span>{expiredRequirementRiskReviews.length}件</span>
                  <p>リスク受容の期限切れ、期限未設定、不正日時を確認します。</p>
                </div>
                {requirementApprovalDetailBlockers.slice(0, 4).map((blocker) => (
                  <div className="validation-row warning" key={blocker.key}>
                    <strong>{blocker.title}</strong>
                    <span>{blocker.status}</span>
                    <p>{blocker.detail}</p>
                  </div>
                ))}
                {requirementApprovalDetailBlockers.length > 4 ? <p>ほか{requirementApprovalDetailBlockers.length - 4}件のブロッカーがあります。</p> : null}
                {!hasRequirementApprovalBlockers ? <p>承認前に表示対象のブロッカーはありません。</p> : null}
              </div>
            ) : null}
            {requirement ? (
              <div className="audit-box">
                <strong>承認者</strong>
                <span>{requirement.approved_by ?? "-"}</span>
                <strong>承認日時</strong>
                <span>{formatDateTime(requirement.approved_at)}</span>
                <strong>承認コメント</strong>
                <span>{requirement.approval_note ?? "-"}</span>
                <strong>最新レビュー</strong>
                <span>{latestRequirementReview ? `${statusLabel(latestRequirementReview.status)} / ${latestRequirementReview.reviewer_role}` : "-"}</span>
              </div>
            ) : null}
            {requirement ? (
              <div className="validation-panel requirement-history-panel" aria-label="Requirement履歴タイムライン">
                <div className="panel-header">
                  <h3>履歴タイムライン</h3>
                  <span className="chip neutral">{requirementHistory.length}件</span>
                </div>
                {requirementHistory.length ? (
                  <div className="history-list">
                    {requirementHistory.map((item) => (
                      <div className="history-item" key={item.id}>
                        <span className={`history-marker ${requirementHistoryTone(item)}`}>
                          <Activity size={14} />
                        </span>
                        <div className="history-content">
                          <div className="history-heading">
                            <strong>{item.title}</strong>
                            <span>{formatDateTime(item.occurred_at)}</span>
                          </div>
                          <p>{requirementHistoryMeta(item)}</p>
                          {item.changes?.length ? (
                            <ul className="history-changes">
                              {item.changes.map((change) => (
                                <li key={`${item.id}-${change.field}`}>{requirementHistoryChangeLabel(change)}</li>
                              ))}
                            </ul>
                          ) : null}
                          {item.reason_summary ? <p>{item.reason_summary}</p> : null}
                          {item.issue_numbers?.length ? <p>関連Issue: {item.issue_numbers.join("、")}</p> : null}
                          {item.stale_issue_draft_count || item.stale_open_api_draft_count ? (
                            <p>
                              再確認対象: Issue {item.stale_issue_draft_count ?? 0}件 / OpenAPI {item.stale_open_api_draft_count ?? 0}件
                            </p>
                          ) : null}
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p>履歴はまだありません。</p>
                )}
              </div>
            ) : null}
            <div className="requirement-editor-grid">
              <label>
                背景
                <textarea value={requirementBackgroundDraft} onChange={(event) => setRequirementBackgroundDraft(event.target.value)} />
              </label>
              <label>
                目的
                <textarea value={requirementGoalDraft} onChange={(event) => setRequirementGoalDraft(event.target.value)} />
              </label>
              <label>
                ユーザーストーリー
                <textarea value={userStoriesDraft} onChange={(event) => setUserStoriesDraft(event.target.value)} />
              </label>
              <label>
                機能要件
                <textarea value={functionalRequirementsDraft} onChange={(event) => setFunctionalRequirementsDraft(event.target.value)} />
              </label>
              <label>
                非機能要件
                <textarea value={nonFunctionalRequirementsDraft} onChange={(event) => setNonFunctionalRequirementsDraft(event.target.value)} />
              </label>
              <label>
                受け入れ条件
                <textarea value={acceptanceCriteriaDraft} onChange={(event) => setAcceptanceCriteriaDraft(event.target.value)} />
              </label>
              <label>
                スコープ外
                <textarea value={outOfScopeDraft} onChange={(event) => setOutOfScopeDraft(event.target.value)} />
              </label>
              <label>
                未解決事項
                <textarea value={requirementOpenQuestionsDraft} onChange={(event) => setRequirementOpenQuestionsDraft(event.target.value)} />
              </label>
              <label>
                リスク
                <textarea value={risksDraft} onChange={(event) => setRisksDraft(event.target.value)} />
              </label>
              <label>
                承認コメント
                <textarea value={requirementApprovalNote} onChange={(event) => setRequirementApprovalNote(event.target.value)} />
              </label>
            </div>
          </section>

          <section className="tool-panel issue-draft-panel" id="issue-draft">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Issueドラフト</p>
                <h3>GitHub Issueドラフト</h3>
              </div>
              <span className={`chip ${statusTone(issueDraft?.status)}`}>{statusLabel(issueDraft?.status)}</span>
            </div>
            <div className="requirement-actions">
              <button className="button primary" type="button" onClick={generateIssueDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                <ClipboardList size={16} />
                Issueドラフトを生成
              </button>
              <button className="button secondary" type="button" onClick={saveIssueDraft} disabled={!issueDraft || isIssueDraftStale || loading}>
                <Save size={16} />
                Issueドラフトを保存
              </button>
              <button className="button secondary" type="button" onClick={approveIssueDraft} disabled={!issueDraft || isIssueDraftStale || loading}>
                <CheckCircle2 size={16} />
                Issueドラフトを承認
              </button>
              <button className="button primary" type="button" onClick={publishIssueDraft} disabled={!canPublishIssueDraft || loading}>
                <Send size={16} />
                GitHub Issueへ公開
              </button>
            </div>
            {isIssueDraftStale ? (
              <div className="validation-panel danger" aria-label="Issueドラフト再生成案内">
                <div className="panel-header">
                  <h3>再生成が必要</h3>
                  <span className="chip warning">Requirement更新済み</span>
                </div>
                <div className="validation-row warning">
                  <strong>このIssueドラフトは古くなっています</strong>
                  <span>Requirementを再承認し、新しいIssueドラフトを生成してください。</span>
                </div>
              </div>
            ) : null}
            <div className="issue-editor-grid">
              <label>
                Issueタイトル
                <input value={issueTitleDraft} onChange={(event) => setIssueTitleDraft(event.target.value)} />
              </label>
              <label>
                ラベル
                <input value={issueLabelsDraft} onChange={(event) => setIssueLabelsDraft(event.target.value)} />
              </label>
              <label className="issue-body-field">
                Issue本文
                <textarea value={issueBodyDraft} onChange={(event) => setIssueBodyDraft(event.target.value)} />
              </label>
              <label>
                Issue受け入れ条件
                <textarea value={issueAcceptanceDraft} onChange={(event) => setIssueAcceptanceDraft(event.target.value)} />
              </label>
            </div>
            {issueDraft?.publish_error ? (
              <div className="validation-panel danger">
                <div className="panel-header">
                  <h3>公開ブロック</h3>
                  <span className="chip danger">{statusLabel(issueDraft.status)}</span>
                </div>
                <div className="validation-row">
                  <strong>GitHub連携</strong>
                  <span>未接続</span>
                  <p>{displayMessage(issueDraft.publish_error)}</p>
                </div>
                <div className="reconnection-actions" aria-label="GitHub再接続">
                  <button className="button secondary" type="button" onClick={startGitHubConnection} disabled={loading || !selectedProjectId}>
                    <GitBranch size={16} />
                    {githubConnectionActionLabel}
                  </button>
                  {githubInstallationUrl ? (
                    <a className="button primary" href={githubInstallationUrl} target="_blank" rel="noreferrer">
                      <GitBranch size={16} />
                      GitHub App設定を開く
                    </a>
                  ) : null}
                </div>
                {hasPendingGitHubReconciliation ? (
                  <>
                    <div className="validation-row warning">
                      <strong>照合</strong>
                      <span>{statusLabel(issueDraft.github_reconciliation?.status)}</span>
                      <p>{displayMessage(issueDraft.github_reconciliation?.safe_error_detail)}</p>
                      {typeof issueDraft.github_reconciliation?.reconciliation_retry_count === "number" ? (
                        <p>再検索回数 {issueDraft.github_reconciliation.reconciliation_retry_count}回</p>
                      ) : null}
                      {issueDraft.github_reconciliation?.next_reconciliation_retry_at ? (
                        <p>次の再検索 {formatDateTime(issueDraft.github_reconciliation.next_reconciliation_retry_at)}</p>
                      ) : null}
                    </div>
                    <div className="reconciliation-grid" aria-label="GitHub公開照合コントロール">
                      <label>
                        GitHub Issue番号
                        <input
                          inputMode="numeric"
                          value={reconciliationIssueNumber}
                          onChange={(event) => setReconciliationIssueNumber(event.target.value)}
                        />
                      </label>
                      <label>
                        GitHub Issue URL
                        <input value={reconciliationIssueUrl} onChange={(event) => setReconciliationIssueUrl(event.target.value)} />
                      </label>
                      <label>
                        再試行承認者
                        <input value={reconciliationApprover} onChange={(event) => setReconciliationApprover(event.target.value)} />
                      </label>
                      <label>
                        再試行理由
                        <select
                          value={reconciliationRetryReasonTemplate}
                          onChange={(event) => setReconciliationRetryReasonTemplate(event.target.value as RetryReasonTemplate)}
                        >
                          {retryReasonTemplates.map((template) => (
                            <option key={template.value} value={template.value}>
                              {template.label}
                            </option>
                          ))}
                        </select>
                      </label>
                      <label className="reconciliation-note">
                        解決メモ
                        <textarea value={reconciliationNote} onChange={(event) => setReconciliationNote(event.target.value)} />
                      </label>
                    </div>
                    {reconciliationMatches.length > 0 ? (
                      <div className="reconciliation-candidates" aria-label="GitHub Issue候補">
                        <div className="panel-header">
                          <h3>候補Issue</h3>
                          <span className="chip warning">{reconciliationMatches.length}件</span>
                          {typeof reconciliationSearchSummary?.search_total_count === "number" ? (
                            <span className="chip neutral">検索総数 {reconciliationSearchSummary.search_total_count}件</span>
                          ) : null}
                          {reconciliationSearchSummary?.search_has_more_results ? (
                            <span className="chip warning">上位{reconciliationSearchSummary.search_result_limit ?? reconciliationMatches.length}件のみ表示</span>
                          ) : null}
                          {reconciliationSearchSummary?.search_incomplete_results ? <span className="chip danger">検索未完了</span> : null}
                        </div>
                        <div className="candidate-list">
                          {reconciliationMatches.map((match) => {
                            const isSelected =
                              reconciliationIssueNumber === String(match.github_issue_number) && reconciliationIssueUrl === match.github_issue_url;
                            return (
                              <div
                                aria-current={isSelected ? "true" : undefined}
                                className={`candidate-row${isSelected ? " selected" : ""}`}
                                key={`${match.github_repository}-${match.github_issue_number}`}
                              >
                                <div>
                                  <strong>
                                    #{match.github_issue_number} {match.github_issue_title ?? "タイトル未取得"}
                                  </strong>
                                  <span>{match.github_repository}</span>
                                  <span className="candidate-meta">
                                    状態 {githubIssueStateLabel(match.github_issue_state)} / 更新 {formatDateTime(match.github_issue_updated_at)} / スコア{" "}
                                    {match.github_issue_score ?? "-"}
                                  </span>
                                  <a className="github-link" href={match.github_issue_url} target="_blank" rel="noreferrer">
                                    {match.github_issue_url}
                                  </a>
                                </div>
                                <div className="candidate-selection">
                                  {isSelected ? <span className="chip success">選択中</span> : null}
                                  <button
                                    aria-pressed={isSelected}
                                    className={`button ${isSelected ? "primary" : "secondary"}`}
                                    type="button"
                                    onClick={() => selectReconciliationMatch(match)}
                                    disabled={loading}
                                  >
                                    <CheckCircle2 size={16} />
                                    {isSelected ? "選択中" : "候補を選択"}
                                  </button>
                                </div>
                              </div>
                            );
                          })}
                        </div>
                      </div>
                    ) : null}
                    <div className="reconciliation-actions">
                      <button
                        className="button secondary"
                        type="button"
                        onClick={reconcileGitHubPublish}
                        disabled={!hasPendingGitHubReconciliation || isGitHubReconciliationCooldownActive || loading}
                      >
                        <RefreshCw size={16} />
                        マーカー検索
                      </button>
                      <button
                        className="button secondary"
                        type="button"
                        onClick={() => resolveGitHubReconciliation("link_existing_issue")}
                        disabled={!hasPendingGitHubReconciliation || loading}
                      >
                        <CheckCircle2 size={16} />
                        既存Issueに紐付け
                      </button>
                      <button
                        className="button primary"
                        type="button"
                        onClick={() => resolveGitHubReconciliation("approve_retry")}
                        disabled={!hasPendingGitHubReconciliation || isGitHubReconciliationCooldownActive || loading}
                      >
                        <Send size={16} />
                        再試行を承認
                      </button>
                    </div>
                  </>
                ) : (
                  <div className="validation-row warning">
                    <strong>照合</strong>
                    <span>照合待ちなし</span>
                    <p>保留中のGitHub照合はありません。</p>
                  </div>
                )}
              </div>
            ) : issueDraft?.github_issue_url ? (
              <div className="validation-panel success">
                <div className="panel-header">
                  <h3>公開済みGitHub Issue</h3>
                  <span className="chip success">公開済み</span>
                </div>
                <div className="validation-row warning">
                  <strong>#{issueDraft.github_issue_number}</strong>
                  <span>公開先</span>
                  <p>
                    <a className="github-link" href={issueDraft.github_issue_url} target="_blank" rel="noreferrer">
                      {issueDraft.github_issue_url}
                    </a>
                  </p>
                </div>
              </div>
            ) : null}
            {issueDraft?.github_reconciliation_history?.length ? (
              <div className="validation-panel" aria-label="GitHub公開照合履歴">
                <div className="panel-header">
                  <h3>照合履歴</h3>
                  <span className="chip neutral">{issueDraft.github_reconciliation_history.length}件</span>
                </div>
                <div className="validation-list">
                  {issueDraft.github_reconciliation_history.map((entry) => (
                    <div className="validation-row warning" key={entry.attempt_id}>
                      <strong>{statusLabel(entry.status)}</strong>
                      <span>開始 {formatDateTime(entry.started_at)}</span>
                      <p>
                        {reconciliationHistorySummary(entry)}
                        {entry.github_issue_url ? (
                          <>
                            <br />
                            <a className="github-link" href={entry.github_issue_url} target="_blank" rel="noreferrer">
                              {entry.github_issue_url}
                            </a>
                          </>
                        ) : null}
                      </p>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </section>

          <section className="tool-panel openapi-draft-panel" id="openapi-draft">
            <div className="panel-header">
              <div>
                <p className="eyebrow">OpenAPIドラフト</p>
                <h3>API契約ドラフト</h3>
              </div>
              <span className={`chip ${statusTone(openApiDraft?.status)}`}>{statusLabel(openApiDraft?.status)}</span>
            </div>
            <div className="requirement-actions">
              <button className="button primary" type="button" onClick={generateOpenApiDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                <FileCode2 size={16} />
                OpenAPIドラフトを生成
              </button>
              <button className="button secondary" type="button" onClick={saveOpenApiDraft} disabled={!openApiDraft || isOpenApiDraftStale || loading}>
                <Save size={16} />
                OpenAPIドラフトを保存
              </button>
              <button className="button secondary" type="button" onClick={validateOpenApiDraft} disabled={!openApiDraft || isOpenApiDraftStale || loading}>
                <CheckCircle2 size={16} />
                OpenAPIを検証
              </button>
            </div>
            {isOpenApiDraftStale ? (
              <div className="validation-panel danger" aria-label="OpenAPIドラフト再生成案内">
                <div className="panel-header">
                  <h3>再生成が必要</h3>
                  <span className="chip warning">Requirement更新済み</span>
                </div>
                <div className="validation-row warning">
                  <strong>このOpenAPIドラフトは古くなっています</strong>
                  <span>Requirementを再承認し、新しいOpenAPIドラフトを生成してください。</span>
                </div>
              </div>
            ) : null}
            <div className="openapi-editor-grid">
              <label>
                OpenAPIタイトル
                <input value={openApiTitleDraft} onChange={(event) => setOpenApiTitleDraft(event.target.value)} />
              </label>
              <label className="openapi-content-field">
                OpenAPI YAML
                <textarea
                  value={openApiContentDraft}
                  onChange={(event) => {
                    setOpenApiContentDraft(event.target.value);
                    setOpenApiValidation(null);
                    setOpenApiReview(null);
                  }}
                />
              </label>
            </div>
            {openApiReview ? (
              <div className={`validation-panel ${openApiReview.status === "action_required" ? "danger" : "success"}`}>
                <div className="panel-header">
                  <h3>レビューブロッカー</h3>
                  <span className={`chip ${openApiReview.status === "action_required" ? "danger" : "success"}`}>{statusLabel(openApiReview.status)}</span>
                </div>
                <div className="validation-list">
                  {openApiReview.improvements.map((message) => (
                    <div className="validation-row" key={message}>
                      <strong>{openApiReview.reviewer_role}</strong>
                      <span>{statusLabel(openApiReview.status)}</span>
                      <p>{displayMessage(message)}</p>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            {openApiValidation ? (
              <div className={`validation-panel ${openApiValidation.valid ? "success" : "danger"}`}>
                <div className="panel-header">
                  <h3>{openApiValidation.valid ? "検証成功" : "検証失敗"}</h3>
                  <span className={`chip ${openApiValidation.valid ? "success" : "danger"}`}>
                    エラー{openApiValidation.errors.length}件 / 警告{openApiValidation.warnings.length}件
                  </span>
                </div>
                {openApiValidation.errors.length > 0 ? (
                  <div className="validation-list">
                    {openApiValidation.errors.map((issue) => (
                      <div className="validation-row" key={`${issue.path}-${issue.code ?? issue.message}`}>
                        <strong>{issue.path}</strong>
                        <span>{issue.code ?? issue.severity}</span>
                        <p>{displayMessage(issue.message)}</p>
                      </div>
                    ))}
                  </div>
                ) : null}
                {openApiValidation.warnings.length > 0 ? (
                  <div className="validation-list">
                    {openApiValidation.warnings.map((issue) => (
                      <div className="validation-row warning" key={`${issue.path}-${issue.code ?? issue.message}`}>
                        <strong>{issue.path}</strong>
                        <span>{issue.code ?? issue.severity}</span>
                        <p>{displayMessage(issue.message)}</p>
                      </div>
                    ))}
                  </div>
                ) : null}
              </div>
            ) : openApiDraft?.validation_errors && openApiDraft.validation_errors.length > 0 ? (
              <div className="validation-panel danger">
                <div className="panel-header">
                  <h3>保存済み検証エラー</h3>
                  <span className="chip danger">エラー{openApiDraft.validation_errors.length}件</span>
                </div>
                <div className="validation-list">
                  {openApiDraft.validation_errors.map((message) => (
                    <div className="validation-row" key={message}>
                      <strong>保存済み</strong>
                      <span>エラー</span>
                      <p>{displayMessage(message)}</p>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </section>
            </>
          )}
        </div>
      </main>
    </div>
  );
}
