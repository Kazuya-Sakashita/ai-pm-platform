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
  Play,
  Plus,
  RefreshCw,
  Save,
  Send,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { apiClient } from "@/lib/api/client";
import { displayMessage, statusLabel, targetLabel, yesNoLabel } from "@/lib/display-labels";
import type { components } from "@/lib/api/schema";

type Project = components["schemas"]["Project"];
type Meeting = components["schemas"]["Meeting"];
type Minutes = components["schemas"]["Minutes"];
type Requirement = components["schemas"]["Requirement"];
type IssueDraft = components["schemas"]["IssueDraft"];
type OpenApiDraft = components["schemas"]["OpenApiDraft"];
type OpenApiValidationResult = components["schemas"]["OpenApiValidationResponse"]["data"];
type Job = components["schemas"]["Job"];
type QueueHealth = components["schemas"]["QueueHealth"];
type Review = components["schemas"]["Review"];
type IntegrationAccount = components["schemas"]["IntegrationAccount"];
type MeetingSourceType = components["schemas"]["MeetingSourceType"];
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

const retryReasonTemplates: { value: RetryReasonTemplate; label: string }[] = [
  { value: "github_issue_absence_confirmed", label: "GitHub上でIssue未作成を確認" },
  { value: "github_search_complete_no_match", label: "GitHub Search完了後も該当Issueなし" },
  { value: "provider_transient_failure_confirmed", label: "外部APIの一時失敗を確認" },
];

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

function errorMessage(error: unknown) {
  const payload = error as ApiErrorPayload;
  return displayMessage(payload.error?.message) || "APIリクエストに失敗しました。";
}

function errorJobId(error: unknown) {
  const payload = error as ApiErrorPayload;
  const value = payload.error?.details?.job_id;
  return typeof value === "string" ? value : undefined;
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
    status === "approved" ||
    status === "connected" ||
    status === "succeeded" ||
    status === "valid" ||
    status === "published" ||
    status === "reconciled" ||
    status === "retry_approved" ||
    status === "local_saved" ||
    status === "healthy"
  ) {
    return "success";
  }
  if (status === "failed" || status === "needs_changes" || status === "invalid" || status === "publish_failed" || status === "unavailable") return "danger";
  if (status === "degraded") return "warning";
  if (status === "error" || status === "revoked") return "danger";
  if (
    status === "in_review" ||
    status === "running" ||
    status === "generating" ||
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
  const [lastReview, setLastReview] = useState<Review | null>(null);
  const [openApiReview, setOpenApiReview] = useState<Review | null>(null);
  const [integrationAccounts, setIntegrationAccounts] = useState<IntegrationAccount[]>([]);
  const [statusMessage, setStatusMessage] = useState("API接続待機中");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);
  const [githubInstallationUrl, setGithubInstallationUrl] = useState("");

  const [projectName, setProjectName] = useState("AI議事録プラットフォーム");
  const [projectRepo, setProjectRepo] = useState("Kazuya-Sakashita/ai-pm-platform");
  const [meetingTitle, setMeetingTitle] = useState("Discordプロダクト同期");
  const [meetingDate, setMeetingDate] = useState(today());
  const [sourceType, setSourceType] = useState<MeetingSourceType>("discord_log");
  const [participants, setParticipants] = useState("Kazuya, プロダクト, エンジニアリング");
  const [rawText, setRawText] = useState(defaultLog);

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
    void loadProjects();
    void loadQueueHealth({ announce: false });
  }, []);

  useEffect(() => {
    if (!selectedProjectId) return;
    setIntegrationAccounts([]);
    setGithubInstallationUrl("");
    void loadMeetings(selectedProjectId);
    void loadIntegrations(selectedProjectId);
  }, [selectedProjectId]);

  function setApiError(message: string) {
    setError(message);
    setStatusMessage("APIエラー");
  }

  async function loadProjects() {
    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.GET("/projects");
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

  async function loadQueueHealth(options: { announce?: boolean } = {}) {
    const announce = options.announce !== false;
    setQueueHealthLoading(true);
    if (announce) setError("");

    try {
      const { data, error: apiError } = await apiClient.GET("/operations/queue-health");
      setQueueHealthLoading(false);

      if (apiError) {
        if (announce) setApiError(errorMessage(apiError));
        return;
      }

      setQueueHealth(data.data);
      if (announce) setStatusMessage("運用状態を更新しました");
    } catch {
      setQueueHealthLoading(false);
      if (announce) setApiError("運用状態を取得できませんでした。");
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

    applyRequirement(requirementResult.data.data);
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

    applyRequirement(data.data);
    setStatusMessage("要件定義を保存しました");
  }

  async function approveRequirement() {
    if (!requirement) {
      setApiError("承認する要件定義がありません。");
      return;
    }

    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/requirements/{requirement_id}/approve", {
      params: { path: { requirement_id: requirement.id } },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    applyRequirement(data.data);
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
    setStatusMessage("要件レビューを依頼しました");
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

  function applyMinutes(nextMinutes: Minutes) {
    setMinutes(nextMinutes);
    setSummaryDraft(nextMinutes.summary);
    setDecisionsDraft(linesToText(nextMinutes.decisions.map((decision) => decision.text)));
    setQuestionsDraft(linesToText(nextMinutes.open_questions));
    setActionsDraft(linesToText(nextMinutes.action_items.map((action) => action.text)));
  }

  function applyRequirement(nextRequirement: Requirement) {
    setRequirement(nextRequirement);
    setIssueDraft(null);
    setOpenApiDraft(null);
    setRequirementBackgroundDraft(nextRequirement.background);
    setRequirementGoalDraft(nextRequirement.goal);
    setUserStoriesDraft(linesToText(nextRequirement.user_stories ?? []));
    setFunctionalRequirementsDraft(linesToText(nextRequirement.functional_requirements));
    setNonFunctionalRequirementsDraft(linesToText(nextRequirement.non_functional_requirements ?? []));
    setAcceptanceCriteriaDraft(linesToText(nextRequirement.acceptance_criteria));
    setOutOfScopeDraft(linesToText(nextRequirement.out_of_scope ?? []));
    setRequirementOpenQuestionsDraft(linesToText(nextRequirement.open_questions ?? []));
    setRisksDraft(linesToText(nextRequirement.risks ?? []));
    clearIssueDrafts();
    clearOpenApiDrafts();
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

  const canPublishIssueDraft =
    issueDraft?.status === "approved" &&
    (openApiDraft?.status === "valid" || openApiDraft?.status === "approved") &&
    openApiReview?.status !== "action_required";
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
  const warningRows = queueHealth?.warnings.slice(0, 3) ?? [];

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
            </div>
          </section>

          {error ? (
            <section className="alert danger" role="alert">
              <AlertTriangle size={18} />
              <span>{error}</span>
            </section>
          ) : null}

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
                </div>
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
                      <div className="failed-job-row" key={`${job.class_name}-${job.active_job_id ?? job.failed_at}`}>
                        <strong>{job.class_name}</strong>
                        <span>{job.queue_name}</span>
                        <span>{formatDateTime(job.failed_at)}</span>
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
              </div>
            </aside>
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
              <button className="button primary" type="button" onClick={approveRequirement} disabled={!requirement || loading}>
                <CheckCircle2 size={16} />
                要件定義を承認
              </button>
              <button className="button" type="button" onClick={requestRequirementReview} disabled={!requirement || loading}>
                <Send size={16} />
                要件レビュー依頼
              </button>
            </div>
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
              <button className="button secondary" type="button" onClick={saveIssueDraft} disabled={!issueDraft || loading}>
                <Save size={16} />
                Issueドラフトを保存
              </button>
              <button className="button secondary" type="button" onClick={approveIssueDraft} disabled={!issueDraft || loading}>
                <CheckCircle2 size={16} />
                Issueドラフトを承認
              </button>
              <button className="button primary" type="button" onClick={publishIssueDraft} disabled={!canPublishIssueDraft || loading}>
                <Send size={16} />
                GitHub Issueへ公開
              </button>
            </div>
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
              <button className="button secondary" type="button" onClick={saveOpenApiDraft} disabled={!openApiDraft || loading}>
                <Save size={16} />
                OpenAPIドラフトを保存
              </button>
              <button className="button secondary" type="button" onClick={validateOpenApiDraft} disabled={!openApiDraft || loading}>
                <CheckCircle2 size={16} />
                OpenAPIを検証
              </button>
            </div>
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
        </div>
      </main>
    </div>
  );
}
