"use client";

import {
  AlertTriangle,
  CheckCircle2,
  CircleDot,
  ClipboardList,
  Database,
  FileCheck2,
  FileCode2,
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
import type { components } from "@/lib/api/schema";

type Project = components["schemas"]["Project"];
type Meeting = components["schemas"]["Meeting"];
type Minutes = components["schemas"]["Minutes"];
type Requirement = components["schemas"]["Requirement"];
type IssueDraft = components["schemas"]["IssueDraft"];
type OpenApiDraft = components["schemas"]["OpenApiDraft"];
type OpenApiValidationResult = components["schemas"]["OpenApiValidationResponse"]["data"];
type Job = components["schemas"]["Job"];
type Review = components["schemas"]["Review"];
type MeetingSourceType = components["schemas"]["MeetingSourceType"];

type ApiErrorPayload = {
  error?: {
    code?: string;
    message?: string;
    details?: Record<string, unknown>;
  };
};

const defaultLog = `alice: Decision: Discord-firstで議事録MVPを切る。
bob: Open question: Review requestの担当者は誰にする？
alice: Action: Meeting WorkspaceからMinutes生成を接続する。`;

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
  return payload.error?.message ?? "API request failed.";
}

function errorJobId(error: unknown) {
  const payload = error as ApiErrorPayload;
  const value = payload.error?.details?.job_id;
  return typeof value === "string" ? value : undefined;
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

function statusTone(status?: string) {
  if (status === "approved" || status === "succeeded" || status === "valid" || status === "published") return "success";
  if (status === "failed" || status === "needs_changes" || status === "invalid" || status === "publish_failed") return "danger";
  if (status === "in_review" || status === "running" || status === "generating" || status === "publishing") return "review";
  return "neutral";
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
  const [lastReview, setLastReview] = useState<Review | null>(null);
  const [openApiReview, setOpenApiReview] = useState<Review | null>(null);
  const [statusMessage, setStatusMessage] = useState("API接続待機中");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const [projectName, setProjectName] = useState("AI議事録プラットフォーム");
  const [projectRepo, setProjectRepo] = useState("Kazuya-Sakashita/ai-pm-platform");
  const [meetingTitle, setMeetingTitle] = useState("Discord Product Sync");
  const [meetingDate, setMeetingDate] = useState(today());
  const [sourceType, setSourceType] = useState<MeetingSourceType>("discord_log");
  const [participants, setParticipants] = useState("Kazuya, Product, Engineering");
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
  const [openApiTitleDraft, setOpenApiTitleDraft] = useState("");
  const [openApiContentDraft, setOpenApiContentDraft] = useState("");

  const selectedProject = useMemo(
    () => projects.find((project) => project.id === selectedProjectId) ?? null,
    [projects, selectedProjectId],
  );

  useEffect(() => {
    void loadProjects();
  }, []);

  useEffect(() => {
    if (!selectedProjectId) return;
    void loadMeetings(selectedProjectId);
  }, [selectedProjectId]);

  function setApiError(message: string) {
    setError(message);
    setStatusMessage("API error");
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
    setStatusMessage(loadedProjects.length > 0 ? "Projects loaded" : "Project未作成");
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

  async function createProject() {
    setLoading(true);
    setError("");
    const { data, error: apiError } = await apiClient.POST("/projects", {
      body: {
        name: projectName,
        github_repo: projectRepo,
        description: "AI PM Platform MVP workspace",
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setProjects((current) => [data.data, ...current]);
    setSelectedProjectId(data.data.id);
    setStatusMessage("Project created");
  }

  async function createMeeting() {
    if (!selectedProjectId) {
      setApiError("Projectを先に作成または選択してください。");
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
    setStatusMessage("Meeting saved");
  }

  async function generateMinutes() {
    if (!selectedMeeting) {
      setApiError("Meetingを先に保存してください。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("Minutes generating");
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
    const { data } = await apiClient.GET("/jobs/{job_id}", {
      params: { path: { job_id: jobId } },
    });
    if (data) setLastJob(data.data);
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
      setApiError(job.safe_error_detail ?? "Minutes generation failed.");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("Minutes job finished without target_id");
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
    setStatusMessage("Minutes generated");
  }

  async function saveMinutes() {
    if (!minutes) {
      setApiError("保存するMinutesがありません。");
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
    setStatusMessage("Minutes saved");
  }

  async function approveMinutes() {
    if (!minutes) {
      setApiError("承認するMinutesがありません。");
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
    setStatusMessage("Minutes approved");
  }

  async function generateRequirement() {
    if (!minutes) {
      setApiError("Requirement生成対象のMinutesがありません。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("Requirements generating");
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
      setApiError(job.safe_error_detail ?? "Requirement generation failed.");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("Requirement job finished without target_id");
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
    setStatusMessage("Requirements generated");
  }

  async function saveRequirement() {
    if (!requirement) {
      setApiError("保存するRequirementがありません。");
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
    setStatusMessage("Requirements saved");
  }

  async function approveRequirement() {
    if (!requirement) {
      setApiError("承認するRequirementがありません。");
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
    setStatusMessage("Requirements approved");
  }

  async function generateIssueDraft() {
    if (!requirement) {
      setApiError("Issue Draft生成対象のRequirementがありません。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("Issue draft generating");
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
      setApiError(job.safe_error_detail ?? "Issue draft generation failed.");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("Issue draft job finished without target_id");
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
    setStatusMessage("Issue draft generated");
  }

  async function saveIssueDraft() {
    if (!issueDraft) {
      setApiError("保存するIssue Draftがありません。");
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
    setStatusMessage("Issue draft saved");
  }

  async function approveIssueDraft() {
    if (!issueDraft) {
      setApiError("承認するIssue Draftがありません。");
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
    setStatusMessage("Issue draft approved");
  }

  async function publishIssueDraft() {
    if (!issueDraft) {
      setApiError("公開するIssue Draftがありません。");
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

    setStatusMessage(data.data.status === "published" ? "GitHub issue published" : "GitHub issue publishing");
  }

  async function generateOpenApiDraft() {
    if (!requirement) {
      setApiError("OpenAPI Draft生成対象のRequirementがありません。");
      return;
    }

    setLoading(true);
    setError("");
    setStatusMessage("OpenAPI draft generating");
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
      setApiError(job.safe_error_detail ?? "OpenAPI draft generation failed.");
      return;
    }

    if (!job.target_id) {
      setStatusMessage("OpenAPI draft job finished without target_id");
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
    setStatusMessage("OpenAPI draft generated");
  }

  async function saveOpenApiDraft() {
    if (!openApiDraft) {
      setApiError("保存するOpenAPI Draftがありません。");
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
    setStatusMessage("OpenAPI draft saved");
  }

  async function validateOpenApiDraft() {
    if (!openApiDraft) {
      setApiError("検証するOpenAPI Draftがありません。");
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
    setStatusMessage(validationResult.data.data.valid ? "OpenAPI validation passed" : "OpenAPI validation failed");
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
      setApiError("Review対象のMinutesがありません。");
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
        positives: ["Minutes draft was generated and stored."],
        improvements: ["Human review is required before generating requirements."],
        priority: ["P0: Approve minutes before requirement generation."],
        next_actions: ["Review summary, decisions, open questions, and action items."],
        issue_numbers: ["#2"],
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setLastReview(data.data);
    setStatusMessage("Review requested");
  }

  async function requestRequirementReview() {
    if (!requirement) {
      setApiError("Review対象のRequirementがありません。");
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
        positives: ["Requirement draft was generated from approved minutes."],
        improvements: ["Open questions must be resolved before GitHub Issue generation."],
        priority: ["P0: Resolve requirement ambiguity before Issue generation."],
        next_actions: ["Review background, goal, acceptance criteria, open questions, and risks."],
        issue_numbers: ["#3"],
      },
    });
    setLoading(false);

    if (apiError) {
      setApiError(errorMessage(apiError));
      return;
    }

    setLastReview(data.data);
    setStatusMessage("Requirement review requested");
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
    setStatusMessage("Meeting selected");
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

  return (
    <div className="app-shell">
      <aside className="sidebar" aria-label="Primary navigation">
        <div className="brand">
          <span className="brand-mark">AP</span>
          <span>AI PM</span>
        </div>
        <nav className="nav-list">
          <a className="nav-item active" href="#meeting">
            <ClipboardList size={16} />
            Meetings
          </a>
          <a className="nav-item" href="#minutes">
            <FileCheck2 size={16} />
            Minutes
          </a>
          <a className="nav-item" href="#requirements">
            <ListChecks size={16} />
            Requirements
          </a>
          <a className="nav-item" href="#issue-draft">
            <ClipboardList size={16} />
            Issue Draft
          </a>
          <a className="nav-item" href="#openapi-draft">
            <FileCode2 size={16} />
            OpenAPI Draft
          </a>
          <a className="nav-item" href="#review">
            <CheckCircle2 size={16} />
            Review
          </a>
        </nav>
      </aside>

      <main className="workspace">
        <header className="top-bar">
          <div>
            <p className="eyebrow">Project</p>
            <h1>{selectedProject?.name ?? "AI議事録プラットフォーム"}</h1>
          </div>
          <div className="top-status">
            <span className={`chip ${error ? "danger" : "success"}`}>{error ? "API error" : statusMessage}</span>
            {lastJob ? <span className={`chip ${statusTone(lastJob.status)}`}>job {lastJob.status}</span> : null}
            <button className="icon-button" type="button" onClick={loadProjects} aria-label="Refresh projects">
              <RefreshCw size={16} />
            </button>
          </div>
        </header>

        <div className="main-grid">
          <section className="context-bar">
            <div>
              <p className="eyebrow">Meeting Workspace</p>
              <h2>Discordログから議事録を生成</h2>
            </div>
            <div className="action-row">
              <button className="button secondary" type="button" onClick={saveMinutes} disabled={!minutes || loading}>
                <Save size={16} />
                Save
              </button>
              <button className="button secondary" type="button" onClick={saveRequirement} disabled={!requirement || loading}>
                <Save size={16} />
                Save Req
              </button>
              <button className="button secondary" type="button" onClick={saveIssueDraft} disabled={!issueDraft || loading}>
                <Save size={16} />
                Save Issue
              </button>
              <button className="button secondary" type="button" onClick={approveIssueDraft} disabled={!issueDraft || loading}>
                <CheckCircle2 size={16} />
                Approve Issue
              </button>
              <button className="button primary" type="button" onClick={publishIssueDraft} disabled={!canPublishIssueDraft || loading}>
                <Send size={16} />
                Publish GitHub
              </button>
              <button className="button secondary" type="button" onClick={saveOpenApiDraft} disabled={!openApiDraft || loading}>
                <Save size={16} />
                Save API
              </button>
              <button className="button secondary" type="button" onClick={validateOpenApiDraft} disabled={!openApiDraft || loading}>
                <CheckCircle2 size={16} />
                Validate API
              </button>
              <button className="button primary" type="button" onClick={generateMinutes} disabled={!selectedMeeting || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <Play size={16} />}
                Generate
              </button>
              <button className="button primary" type="button" onClick={generateRequirement} disabled={!minutes || minutes.status !== "approved" || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <ListChecks size={16} />}
                Requirements
              </button>
              <button className="button primary" type="button" onClick={generateIssueDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <ClipboardList size={16} />}
                Issue Draft
              </button>
              <button className="button primary" type="button" onClick={generateOpenApiDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <FileCode2 size={16} />}
                OpenAPI
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
                  <h3>Project</h3>
                  <span className="chip neutral">{projects.length}</span>
                </div>
                <label>
                  Name
                  <input value={projectName} onChange={(event) => setProjectName(event.target.value)} />
                </label>
                <label>
                  GitHub repo
                  <input value={projectRepo} onChange={(event) => setProjectRepo(event.target.value)} />
                </label>
                <button className="button full-width" type="button" onClick={createProject} disabled={loading}>
                  <Plus size={16} />
                  Create Project
                </button>
                <select value={selectedProjectId} onChange={(event) => setSelectedProjectId(event.target.value)}>
                  <option value="">Project未選択</option>
                  {projects.map((project) => (
                    <option key={project.id} value={project.id}>
                      {project.name}
                    </option>
                  ))}
                </select>
              </section>

              <section className="tool-panel">
                <div className="panel-header">
                  <h3>Meetings</h3>
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
                  {meetings.length === 0 ? <p className="empty">Meetingなし</p> : null}
                </div>
              </section>
            </div>

            <section className="tool-panel transcript-panel" id="meeting">
              <div className="panel-header">
                <h3>Transcript</h3>
                <span className={`chip ${selectedMeeting ? "success" : "neutral"}`}>{selectedMeeting ? "saved" : "draft"}</span>
              </div>
              <div className="form-grid">
                <label>
                  Title
                  <input value={meetingTitle} onChange={(event) => setMeetingTitle(event.target.value)} />
                </label>
                <label>
                  Date
                  <input type="date" value={meetingDate} onChange={(event) => setMeetingDate(event.target.value)} />
                </label>
                <label>
                  Source
                  <select value={sourceType} onChange={(event) => setSourceType(event.target.value as MeetingSourceType)}>
                    <option value="discord_log">Discord log</option>
                    <option value="manual">Manual</option>
                    <option value="transcript">Transcript</option>
                  </select>
                </label>
              </div>
              <label>
                Participants
                <input value={participants} onChange={(event) => setParticipants(event.target.value)} />
              </label>
              <label className="fill">
                Raw text
                <textarea value={rawText} onChange={(event) => setRawText(event.target.value)} />
              </label>
              <button className="button full-width" type="button" onClick={createMeeting} disabled={loading}>
                <Database size={16} />
                Save Meeting
              </button>
            </section>

            <section className="tool-panel minutes-panel" id="minutes">
              <div className="panel-header">
                <h3>Minutes editor</h3>
                <span className={`chip ${statusTone(minutes?.status)}`}>{minutes?.status ?? "not generated"}</span>
              </div>
              <label>
                Summary
                <textarea className="summary-editor" value={summaryDraft} onChange={(event) => setSummaryDraft(event.target.value)} />
              </label>
              <div className="editor-columns">
                <label>
                  Decisions
                  <textarea value={decisionsDraft} onChange={(event) => setDecisionsDraft(event.target.value)} />
                </label>
                <label>
                  Open questions
                  <textarea value={questionsDraft} onChange={(event) => setQuestionsDraft(event.target.value)} />
                </label>
              </div>
              <label className="fill">
                Action items
                <textarea value={actionsDraft} onChange={(event) => setActionsDraft(event.target.value)} />
              </label>
            </section>

            <aside className="inspector" id="review">
              <div className="panel-header">
                <h3>Review gate</h3>
                <span className={`chip ${minutes?.status === "approved" ? "success" : "danger"}`}>
                  {minutes?.status === "approved" ? "clear" : "blocked"}
                </span>
              </div>
              <div className="gate-stack">
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Meeting saved</span>
                  <strong>{selectedMeeting ? "yes" : "no"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Minutes generated</span>
                  <strong>{minutes ? "yes" : "no"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Review requested</span>
                  <strong>{lastReview ? "yes" : "no"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Requirements generated</span>
                  <strong>{requirement ? "yes" : "no"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Requirements approved</span>
                  <strong>{requirement?.status === "approved" ? "yes" : "no"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Issue draft generated</span>
                  <strong>{issueDraft ? "yes" : "no"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>Issue draft approved</span>
                  <strong>{issueDraft?.status === "approved" || issueDraft?.status === "published" ? "approved" : issueDraft?.status === "publish_failed" ? "failed" : "pending"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>OpenAPI draft generated</span>
                  <strong>{openApiDraft ? "yes" : "no"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>OpenAPI validated</span>
                  <strong>{openApiDraft?.status === "valid" || openApiDraft?.status === "approved" ? "valid" : openApiDraft?.status === "invalid" ? "invalid" : "pending"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>OpenAPI blocker</span>
                  <strong>{openApiReview ? openApiReview.status : "clear"}</strong>
                </div>
                <div className="gate-row">
                  <CircleDot size={16} />
                  <span>GitHub issue published</span>
                  <strong>{issueDraft?.github_issue_url ? "published" : issueDraft?.status === "publish_failed" ? "failed" : "pending"}</strong>
                </div>
              </div>
              <button className="button full-width" type="button" onClick={requestMinutesReview} disabled={!minutes || loading}>
                <Send size={16} />
                Request Review
              </button>
              <button className="button primary full-width" type="button" onClick={approveMinutes} disabled={!minutes || loading}>
                <CheckCircle2 size={16} />
                Approve Minutes
              </button>
              <div className="audit-box">
                <strong>Latest job</strong>
                <span>{lastJob ? `${lastJob.status} / ${lastJob.target_type}` : "-"}</span>
                <strong>Model</strong>
                <span>{requirement?.generated_by_model ?? minutes?.generated_by_model ?? "-"}</span>
                <strong>Review</strong>
                <span>{lastReview ? `${lastReview.status} / ${lastReview.reviewer_role}` : "-"}</span>
                <strong>API blocker</strong>
                <span>{openApiReview ? `${openApiReview.status} / ${openApiReview.reviewer_role}` : "-"}</span>
              </div>
            </aside>
          </section>

          <section className="tool-panel requirement-panel" id="requirements">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Requirement Workspace</p>
                <h3>Requirement draft</h3>
              </div>
              <span className={`chip ${statusTone(requirement?.status)}`}>{requirement?.status ?? "not generated"}</span>
            </div>
            <div className="requirement-actions">
              <button className="button primary" type="button" onClick={generateRequirement} disabled={!minutes || minutes.status !== "approved" || loading}>
                <ListChecks size={16} />
                Generate Requirements
              </button>
              <button className="button secondary" type="button" onClick={saveRequirement} disabled={!requirement || loading}>
                <Save size={16} />
                Save Requirements
              </button>
              <button className="button primary" type="button" onClick={approveRequirement} disabled={!requirement || loading}>
                <CheckCircle2 size={16} />
                Approve Requirements
              </button>
              <button className="button" type="button" onClick={requestRequirementReview} disabled={!requirement || loading}>
                <Send size={16} />
                Request Requirement Review
              </button>
            </div>
            <div className="requirement-editor-grid">
              <label>
                Background
                <textarea value={requirementBackgroundDraft} onChange={(event) => setRequirementBackgroundDraft(event.target.value)} />
              </label>
              <label>
                Goal
                <textarea value={requirementGoalDraft} onChange={(event) => setRequirementGoalDraft(event.target.value)} />
              </label>
              <label>
                User stories
                <textarea value={userStoriesDraft} onChange={(event) => setUserStoriesDraft(event.target.value)} />
              </label>
              <label>
                Functional requirements
                <textarea value={functionalRequirementsDraft} onChange={(event) => setFunctionalRequirementsDraft(event.target.value)} />
              </label>
              <label>
                Non-functional requirements
                <textarea value={nonFunctionalRequirementsDraft} onChange={(event) => setNonFunctionalRequirementsDraft(event.target.value)} />
              </label>
              <label>
                Acceptance criteria
                <textarea value={acceptanceCriteriaDraft} onChange={(event) => setAcceptanceCriteriaDraft(event.target.value)} />
              </label>
              <label>
                Out of scope
                <textarea value={outOfScopeDraft} onChange={(event) => setOutOfScopeDraft(event.target.value)} />
              </label>
              <label>
                Open questions
                <textarea value={requirementOpenQuestionsDraft} onChange={(event) => setRequirementOpenQuestionsDraft(event.target.value)} />
              </label>
              <label>
                Risks
                <textarea value={risksDraft} onChange={(event) => setRisksDraft(event.target.value)} />
              </label>
            </div>
          </section>

          <section className="tool-panel issue-draft-panel" id="issue-draft">
            <div className="panel-header">
              <div>
                <p className="eyebrow">Issue Draft</p>
                <h3>GitHub issue draft</h3>
              </div>
              <span className={`chip ${statusTone(issueDraft?.status)}`}>{issueDraft?.status ?? "not generated"}</span>
            </div>
            <div className="requirement-actions">
              <button className="button primary" type="button" onClick={generateIssueDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                <ClipboardList size={16} />
                Generate Issue Draft
              </button>
              <button className="button secondary" type="button" onClick={saveIssueDraft} disabled={!issueDraft || loading}>
                <Save size={16} />
                Save Issue Draft
              </button>
              <button className="button secondary" type="button" onClick={approveIssueDraft} disabled={!issueDraft || loading}>
                <CheckCircle2 size={16} />
                Approve Issue Draft
              </button>
              <button className="button primary" type="button" onClick={publishIssueDraft} disabled={!canPublishIssueDraft || loading}>
                <Send size={16} />
                Publish GitHub Issue
              </button>
            </div>
            <div className="issue-editor-grid">
              <label>
                Issue title
                <input value={issueTitleDraft} onChange={(event) => setIssueTitleDraft(event.target.value)} />
              </label>
              <label>
                Labels
                <input value={issueLabelsDraft} onChange={(event) => setIssueLabelsDraft(event.target.value)} />
              </label>
              <label className="issue-body-field">
                Issue body
                <textarea value={issueBodyDraft} onChange={(event) => setIssueBodyDraft(event.target.value)} />
              </label>
              <label>
                Issue acceptance criteria
                <textarea value={issueAcceptanceDraft} onChange={(event) => setIssueAcceptanceDraft(event.target.value)} />
              </label>
            </div>
            {issueDraft?.publish_error ? (
              <div className="validation-panel danger">
                <div className="panel-header">
                  <h3>Publish blocked</h3>
                  <span className="chip danger">{issueDraft.status}</span>
                </div>
                <div className="validation-row">
                  <strong>GitHub</strong>
                  <span>integration</span>
                  <p>{issueDraft.publish_error}</p>
                </div>
              </div>
            ) : issueDraft?.github_issue_url ? (
              <div className="validation-panel success">
                <div className="panel-header">
                  <h3>GitHub issue</h3>
                  <span className="chip success">published</span>
                </div>
                <div className="validation-row warning">
                  <strong>#{issueDraft.github_issue_number}</strong>
                  <span>GitHub</span>
                  <p>{issueDraft.github_issue_url}</p>
                </div>
              </div>
            ) : null}
          </section>

          <section className="tool-panel openapi-draft-panel" id="openapi-draft">
            <div className="panel-header">
              <div>
                <p className="eyebrow">OpenAPI Draft</p>
                <h3>API contract draft</h3>
              </div>
              <span className={`chip ${statusTone(openApiDraft?.status)}`}>{openApiDraft?.status ?? "not generated"}</span>
            </div>
            <div className="requirement-actions">
              <button className="button primary" type="button" onClick={generateOpenApiDraft} disabled={!requirement || requirement.status !== "approved" || loading}>
                <FileCode2 size={16} />
                Generate OpenAPI Draft
              </button>
              <button className="button secondary" type="button" onClick={saveOpenApiDraft} disabled={!openApiDraft || loading}>
                <Save size={16} />
                Save OpenAPI Draft
              </button>
              <button className="button secondary" type="button" onClick={validateOpenApiDraft} disabled={!openApiDraft || loading}>
                <CheckCircle2 size={16} />
                Validate OpenAPI
              </button>
            </div>
            <div className="openapi-editor-grid">
              <label>
                OpenAPI title
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
                  <h3>Review blocker</h3>
                  <span className={`chip ${openApiReview.status === "action_required" ? "danger" : "success"}`}>{openApiReview.status}</span>
                </div>
                <div className="validation-list">
                  {openApiReview.improvements.map((message) => (
                    <div className="validation-row" key={message}>
                      <strong>{openApiReview.reviewer_role}</strong>
                      <span>{openApiReview.status}</span>
                      <p>{message}</p>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
            {openApiValidation ? (
              <div className={`validation-panel ${openApiValidation.valid ? "success" : "danger"}`}>
                <div className="panel-header">
                  <h3>{openApiValidation.valid ? "Validation passed" : "Validation failed"}</h3>
                  <span className={`chip ${openApiValidation.valid ? "success" : "danger"}`}>
                    {openApiValidation.errors.length} errors / {openApiValidation.warnings.length} warnings
                  </span>
                </div>
                {openApiValidation.errors.length > 0 ? (
                  <div className="validation-list">
                    {openApiValidation.errors.map((issue) => (
                      <div className="validation-row" key={`${issue.path}-${issue.code ?? issue.message}`}>
                        <strong>{issue.path}</strong>
                        <span>{issue.code ?? issue.severity}</span>
                        <p>{issue.message}</p>
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
                        <p>{issue.message}</p>
                      </div>
                    ))}
                  </div>
                ) : null}
              </div>
            ) : openApiDraft?.validation_errors && openApiDraft.validation_errors.length > 0 ? (
              <div className="validation-panel danger">
                <div className="panel-header">
                  <h3>Saved validation errors</h3>
                  <span className="chip danger">{openApiDraft.validation_errors.length} errors</span>
                </div>
                <div className="validation-list">
                  {openApiDraft.validation_errors.map((message) => (
                    <div className="validation-row" key={message}>
                      <strong>saved</strong>
                      <span>error</span>
                      <p>{message}</p>
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
