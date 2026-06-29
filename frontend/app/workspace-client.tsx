"use client";

import {
  AlertTriangle,
  CheckCircle2,
  CircleDot,
  ClipboardList,
  Database,
  FileCheck2,
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
  if (status === "approved" || status === "succeeded") return "success";
  if (status === "failed" || status === "needs_changes") return "danger";
  if (status === "in_review" || status === "running" || status === "generating") return "review";
  return "neutral";
}

export default function MeetingWorkspace() {
  const [projects, setProjects] = useState<Project[]>([]);
  const [selectedProjectId, setSelectedProjectId] = useState("");
  const [meetings, setMeetings] = useState<Meeting[]>([]);
  const [selectedMeeting, setSelectedMeeting] = useState<Meeting | null>(null);
  const [minutes, setMinutes] = useState<Minutes | null>(null);
  const [lastJob, setLastJob] = useState<Job | null>(null);
  const [lastReview, setLastReview] = useState<Review | null>(null);
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
    clearMinutesDrafts();
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

  async function requestReview() {
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

  function selectMeeting(meeting: Meeting) {
    setSelectedMeeting(meeting);
    setMinutes(null);
    clearMinutesDrafts();
    setStatusMessage("Meeting selected");
  }

  function applyMinutes(nextMinutes: Minutes) {
    setMinutes(nextMinutes);
    setSummaryDraft(nextMinutes.summary);
    setDecisionsDraft(linesToText(nextMinutes.decisions.map((decision) => decision.text)));
    setQuestionsDraft(linesToText(nextMinutes.open_questions));
    setActionsDraft(linesToText(nextMinutes.action_items.map((action) => action.text)));
  }

  function clearMinutesDrafts() {
    setSummaryDraft("");
    setDecisionsDraft("");
    setQuestionsDraft("");
    setActionsDraft("");
  }

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
              <button className="button primary" type="button" onClick={generateMinutes} disabled={!selectedMeeting || loading}>
                {loading ? <Loader2 className="spin" size={16} /> : <Play size={16} />}
                Generate
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
              </div>
              <button className="button full-width" type="button" onClick={requestReview} disabled={!minutes || loading}>
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
                <span>{minutes?.generated_by_model ?? "-"}</span>
                <strong>Review</strong>
                <span>{lastReview ? `${lastReview.status} / ${lastReview.reviewer_role}` : "-"}</span>
              </div>
            </aside>
          </section>
        </div>
      </main>
    </div>
  );
}
