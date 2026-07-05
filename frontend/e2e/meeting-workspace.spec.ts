import { expect, test, type APIRequestContext, type Page } from "@playwright/test";

const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1";

test.describe("Meeting Workspace", () => {
  type GenerationFailure = {
    name: string;
    code: string;
    message: string;
    expectedMessage: string;
    status: number;
    jobId: string;
    requestId?: string;
  };
  type ReconciliationResolutionAction = "approve_retry" | "link_existing_issue";
  type ReconciliationMatch = {
    github_issue_number: number;
    github_issue_url: string;
    github_repository: string;
    github_issue_title?: string;
    github_issue_state?: "open" | "closed";
    github_issue_updated_at?: string;
    github_issue_score?: number;
    github_issue_api_id?: number;
    github_issue_node_id?: string;
  };
  type ReconciliationScenario = {
    resolutionAction: ReconciliationResolutionAction;
    resolutionNote: string;
    expectedResolutionApprover?: string;
    expectedRetryReasonTemplate?: string;
    expectedGithubIssueNumber?: number;
    expectedGithubIssueUrl?: string;
    markerSearchMatches?: ReconciliationMatch[];
    markerSearchTotalCount?: number;
    markerSearchIncompleteResults?: boolean;
    markerSearchResultLimit?: number;
    reconciliationRetryCount?: number;
    nextReconciliationRetryAt?: string;
    apiError?: {
      code: string;
      message: string;
      status: number;
      jobId: string;
    };
  };
  type DmAnonymizationFailure = {
    status: number;
    code: string;
    message: string;
    expectedMessage: string;
  };

  const providerFailures: GenerationFailure[] = [
    {
      name: "OpenAI upstream failure",
      code: "openai_api_error",
      message: "OpenAI request failed. Retry later or check integration settings.",
      expectedMessage: "OpenAIリクエストに失敗しました。",
      status: 502,
      jobId: "job_openai_upstream",
      requestId: "req_openai_upstream",
    },
    {
      name: "invalid AI response",
      code: "invalid_ai_response",
      message: "AI response did not match the expected minutes schema.",
      expectedMessage: "AI応答が想定された議事録形式に一致しませんでした。",
      status: 502,
      jobId: "job_invalid_ai_response",
      requestId: "req_invalid_ai_response",
    },
    {
      name: "OpenAI rate limit",
      code: "rate_limit_exceeded",
      message: "OpenAI request was rate limited. Retry after the provider limit resets.",
      expectedMessage: "OpenAIのレート制限に達しました。",
      status: 429,
      jobId: "job_rate_limit",
      requestId: "req_rate_limit",
    },
  ];

  async function expectApiHealth(request: APIRequestContext) {
    const health = await request.get(`${apiBaseUrl}/health`);
    expect(health.ok(), `Rails API must be running at ${apiBaseUrl}`).toBe(true);
  }

  async function createProject(page: Page, projectName: string) {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Discordログから議事録を生成" })).toBeVisible();
    await page.getByLabel("名称").fill(projectName);
    await page.getByLabel("GitHubリポジトリ").fill("Kazuya-Sakashita/ai-pm-platform");
    await page.getByRole("button", { name: "プロジェクト作成" }).click();
    await expect(page.getByRole("heading", { name: projectName })).toBeVisible();
  }

  async function saveMeeting(page: Page, meetingTitle: string, rawText: string) {
    await page.locator("#meeting").getByLabel("タイトル").fill(meetingTitle);
    await page.getByLabel("原文ログ").fill(rawText);
    await page.getByRole("button", { name: "会議を保存" }).click();
    await expect(page.locator("header").getByText("会議を保存しました")).toBeVisible();
  }

  async function mockExistingDmImportForAnonymization(
    page: Page,
    options: { deleteFailure?: DmAnonymizationFailure } = {},
  ) {
    const now = new Date().toISOString();
    let deleted = false;
    let deleteRequestCount = 0;
    const project = {
      id: "project-dm-anonymization",
      name: "DM Anonymization Project",
      github_repo: "Kazuya-Sakashita/ai-pm-platform",
      description: "Mocked project for DM anonymization failure paths.",
      status: "active",
      created_at: now,
      updated_at: now,
    };
    const conversationImport = {
      id: "conversation-import-dm-anonymization",
      project_id: project.id,
      source_type: "discord_dm_paste",
      title: "DM匿名化E2E",
      raw_text: "依頼者: 削除前にキャンセルと失敗を確認する。",
      redacted_text: "依頼者: 削除前にキャンセルと失敗を確認する。",
      participants: [{ display_name: "依頼者", role: "requester" }],
      consent_confirmed: true,
      consent_statement_version: "discord-dm-manual-import-v1",
      status: "approved",
      safety_flags: [],
      blocked_reasons: [],
      raw_text_retention_expires_at: now,
      raw_text_purged_at: null,
      retention_expires_at: now,
      anonymized_at: null,
      created_at: now,
      updated_at: now,
    };

    await page.route("**/api/v1/operations/queue-health", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            status: "healthy",
            checked_at: now,
            heartbeat_stale_after_seconds: 60,
            oldest_unfinished_threshold_seconds: 300,
            workers: [],
            queues: [],
            failed_executions: { count: 0 },
            failed_job_samples: [],
            recurring_tasks: [],
            product_jobs: {
              by_status: [],
              recent_failed_count: 0,
            },
            warnings: [],
          },
        }),
      });
    });
    await page.route("**/api/v1/projects", async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [project] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/meetings`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/integrations`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/memberships**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: [
            {
              id: "membership-local-demo-owner",
              project_id: project.id,
              actor_id: "local-demo-owner",
              role: "owner",
              status: "active",
              created_at: now,
              updated_at: now,
            },
          ],
          meta: { total_count: 1 },
        }),
      });
    });
    await page.route(`**/api/v1/projects/${project.id}/conversation-imports`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: deleted ? [] : [conversationImport], meta: { total_count: deleted ? 0 : 1 } }),
      });
    });
    await page.route(`**/api/v1/conversation-imports/${conversationImport.id}`, async (route) => {
      if (route.request().method() === "DELETE") {
        deleteRequestCount += 1;
        if (options.deleteFailure) {
          await route.fulfill({
            status: options.deleteFailure.status,
            contentType: "application/json",
            body: JSON.stringify({
              error: {
                code: options.deleteFailure.code,
                message: options.deleteFailure.message,
              },
            }),
          });
          return;
        }

        deleted = true;
        await route.fulfill({ status: 204 });
        return;
      }

      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: conversationImport }) });
    });

    await page.goto("/");
    await expect(page.getByRole("heading", { name: project.name })).toBeVisible();
    await expect(page.getByLabel("DMインポート一覧").getByRole("button", { name: /DM匿名化E2E/ })).toBeVisible();
    await expect(page.locator("#conversation-import").getByRole("button", { name: "DM匿名化" })).toBeEnabled();

    return {
      conversationImport,
      deleteRequestCount: () => deleteRequestCount,
    };
  }

  async function mockGenerationFailure(page: Page, failure: GenerationFailure) {
    const now = new Date().toISOString();

    await page.route("**/api/v1/meetings/*/generate-minutes", async (route) => {
      await route.fulfill({
        status: failure.status,
        contentType: "application/json",
        body: JSON.stringify({
          error: {
            code: failure.code,
            message: failure.message,
            details: {
              job_id: failure.jobId,
              request_id: failure.requestId,
            },
          },
          request_id: "playwright-request",
        }),
      });
    });

    await page.route(`**/api/v1/jobs/${failure.jobId}`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            id: failure.jobId,
            project_id: "playwright-project",
            job_type: "ai_generation",
            status: "failed",
            target_type: "minutes",
            progress: 100,
            error_code: failure.code,
            error_message: "Provider failed",
            safe_error_detail: failure.message,
            created_at: now,
            updated_at: now,
          },
        }),
      });
    });
  }

  async function mockPendingGitHubReconciliationWorkflow(
    page: Page,
    scenario: ReconciliationScenario = {
      resolutionAction: "approve_retry",
      resolutionNote: "Confirmed that no GitHub Issue exists.",
    },
  ) {
    const now = new Date().toISOString();
    const githubIssueNumber = 42;
    const githubIssueUrl = "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42";
    const expectedGithubIssueNumber = scenario.expectedGithubIssueNumber ?? githubIssueNumber;
    const expectedGithubIssueUrl = scenario.expectedGithubIssueUrl ?? githubIssueUrl;
    const expectedResolutionApprover = scenario.expectedResolutionApprover ?? "Kazuya Reviewer";
    const expectedRetryReasonTemplate = scenario.expectedRetryReasonTemplate ?? "github_issue_absence_confirmed";
    const retryReasonLabels: Record<string, string> = {
      github_issue_absence_confirmed: "GitHub上でIssue未作成を確認したため1回だけ再試行を承認します。",
      github_search_complete_no_match: "GitHub Search完了後も該当Issueがないため再試行を承認します。",
      provider_transient_failure_confirmed: "外部APIの一時的な失敗であり二重作成リスクが低いことを確認しました。",
    };
    const expectedRetryReasonLabel = retryReasonLabels[expectedRetryReasonTemplate] ?? expectedRetryReasonTemplate;
    let reconciliationResolved = false;

    const project = {
      id: "project-github-reconciliation",
      name: "Mock GitHub Reconciliation Project",
      github_repo: "Kazuya-Sakashita/ai-pm-platform",
      description: "Mocked project for reconciliation UI.",
      status: "active",
      created_at: now,
      updated_at: now,
    };
    const meeting = {
      id: "meeting-github-reconciliation",
      project_id: project.id,
      title: "Mock GitHub Reconciliation Meeting",
      source_type: "discord_log",
      meeting_date: "2026-07-01",
      participants: ["Kazuya", "Engineering"],
      raw_text: "alice: Decision: reconcile a pending GitHub Issue publish.",
      created_at: now,
      updated_at: now,
    };
    const minutes = {
      id: "minutes-github-reconciliation",
      meeting_id: meeting.id,
      status: "approved",
      summary: "Reconcile a pending GitHub Issue publish.",
      decisions: [{ text: "Use pending reconciliation attempt summary." }],
      open_questions: [],
      action_items: [{ text: "Approve one controlled retry.", status: "open" }],
      generated_by_model: "mock-provider",
      created_at: now,
      updated_at: now,
    };
    const requirement = {
      id: "requirement-github-reconciliation",
      minutes_id: minutes.id,
      status: "approved",
      background: "A GitHub Issue may already exist after a publish timeout.",
      goal: "Resolve pending GitHub reconciliation from the workspace.",
      user_stories: ["As a reviewer, I can approve one controlled retry."],
      functional_requirements: ["Show reconciliation controls only for pending attempts."],
      non_functional_requirements: ["Keep reconciliation auditable."],
      acceptance_criteria: ["Given a pending attempt, when the draft loads, then controls are visible."],
      out_of_scope: [],
      open_questions: [],
      risks: ["Duplicate GitHub Issues."],
      generated_by_model: "mock-provider",
      created_at: now,
      updated_at: now,
    };
    const pendingReconciliationHistory = [
      {
        attempt_id: "attempt-github-reconciliation",
        status: "reconciliation_required",
        safe_error_code: "github_publish_reconciliation_required",
        safe_error_detail: "GitHub issue may have been created. Reconciliation is required.",
        github_repository: project.github_repo,
        github_issue_number: githubIssueNumber,
        github_issue_url: githubIssueUrl,
        reconciliation_retry_count: scenario.reconciliationRetryCount ?? 0,
        next_reconciliation_retry_at: scenario.nextReconciliationRetryAt,
        reconciliation_cooldown_active: Boolean(scenario.nextReconciliationRetryAt && Date.parse(scenario.nextReconciliationRetryAt) > Date.now()),
        started_at: now,
        completed_at: now,
      },
      {
        attempt_id: "attempt-github-failed",
        status: "failed",
        safe_error_code: "github_integration_not_connected",
        safe_error_detail: "GitHub integration is not connected.",
        github_repository: project.github_repo,
        reconciliation_retry_count: 0,
        started_at: now,
        completed_at: now,
      },
    ];
    const pendingIssueDraft = {
      id: "issue-draft-github-reconciliation",
      requirement_id: requirement.id,
      status: "publish_failed",
      title: "Resolve pending GitHub reconciliation",
      body: "## Background\nA GitHub Issue may already exist after a publish timeout.",
      acceptance_criteria: ["Controlled retry is explicitly approved."],
      labels: ["github", "reconciliation"],
      publish_error: "GitHub issue may have been created. Reconciliation is required.",
      github_reconciliation: {
        pending: true,
        attempt_id: "attempt-github-reconciliation",
        status: "reconciliation_required",
        safe_error_code: "github_publish_reconciliation_required",
        safe_error_detail: "GitHub issue may have been created. Reconciliation is required.",
        github_issue_number: githubIssueNumber,
        github_issue_url: githubIssueUrl,
        reconciliation_retry_count: scenario.reconciliationRetryCount,
        next_reconciliation_retry_at: scenario.nextReconciliationRetryAt,
        reconciliation_cooldown_active: Boolean(scenario.nextReconciliationRetryAt && Date.parse(scenario.nextReconciliationRetryAt) > Date.now()),
        completed_at: now,
      },
      github_reconciliation_history: pendingReconciliationHistory,
      created_at: now,
      updated_at: now,
    };
    const approvedIssueDraft = {
      ...pendingIssueDraft,
      status: "approved",
      publish_error: undefined,
      github_reconciliation: { pending: false },
      github_reconciliation_history: [
        {
          ...pendingReconciliationHistory[0],
          status: "retry_approved",
          safe_error_code: undefined,
          safe_error_detail: undefined,
          retry_approver: expectedResolutionApprover,
          retry_reason_template: expectedRetryReasonTemplate,
          retry_reason_template_label: expectedRetryReasonLabel,
          completed_at: now,
        },
        pendingReconciliationHistory[1],
      ],
    };
    const linkedIssueDraft = {
      ...pendingIssueDraft,
      status: "published",
      publish_error: undefined,
      github_issue_number: expectedGithubIssueNumber,
      github_issue_url: expectedGithubIssueUrl,
      github_reconciliation: { pending: false },
      github_reconciliation_history: [
        {
          ...pendingReconciliationHistory[0],
          status: "reconciled",
          safe_error_code: undefined,
          safe_error_detail: undefined,
          github_issue_number: expectedGithubIssueNumber,
          github_issue_url: expectedGithubIssueUrl,
          completed_at: now,
        },
        pendingReconciliationHistory[1],
      ],
    };

    await page.route("**/api/v1/operations/queue-health", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            status: "degraded",
            checked_at: now,
            heartbeat_stale_after_seconds: 60,
            oldest_unfinished_threshold_seconds: 300,
            workers: [],
            queues: [{ queue_name: "default", unfinished_count: 0 }],
            failed_executions: { count: 0 },
            failed_job_samples: [],
            recurring_tasks: [],
            product_jobs: {
              by_status: [
                { status: "queued", count: 0 },
                { status: "running", count: 0 },
                { status: "succeeded", count: 0 },
                { status: "failed", count: 0 },
                { status: "cancelled", count: 0 },
              ],
              recent_failed_count: 0,
            },
            warnings: ["Solid Queue worker heartbeatが確認できません。"],
          },
        }),
      });
    });

    await page.route("**/api/v1/projects", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: [project] }),
      });
    });

    await page.route(`**/api/v1/projects/${project.id}/meetings`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: [meeting] }),
      });
    });

    await page.route(`**/api/v1/projects/${project.id}/integrations`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: [
            {
              id: "integration-github-reconciliation",
              project_id: project.id,
              provider: "github",
              status: "error",
              repository_owner: "Kazuya-Sakashita",
              repository_name: "ai-pm-platform",
              github_installation_id: "987654",
              github_account_login: "Kazuya-Sakashita",
              github_account_type: "User",
              granted_permissions: { metadata: "read", issues: "write" },
              last_error_safe: "GitHub integration is not connected.",
              created_at: now,
              updated_at: now,
            },
          ],
        }),
      });
    });
    await page.route(`**/api/v1/projects/${project.id}/memberships**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: [
            {
              id: "membership-local-demo-owner",
              project_id: project.id,
              actor_id: "local-demo-owner",
              role: "owner",
              status: "active",
              created_at: now,
              updated_at: now,
            },
          ],
          meta: { total_count: 1 },
        }),
      });
    });

    await page.route(`**/api/v1/projects/${project.id}/conversation-imports`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: [], meta: { total_count: 0 } }),
      });
    });

    await page.route(`**/api/v1/meetings/${meeting.id}/generate-minutes`, async (route) => {
      await route.fulfill({
        status: 202,
        contentType: "application/json",
        body: JSON.stringify({ data: { job_id: "job-minutes-github-reconciliation", status: "succeeded" } }),
      });
    });

    await page.route(`**/api/v1/minutes/${minutes.id}/generate-requirement`, async (route) => {
      await route.fulfill({
        status: 202,
        contentType: "application/json",
        body: JSON.stringify({ data: { job_id: "job-requirement-github-reconciliation", status: "succeeded" } }),
      });
    });

    await page.route(`**/api/v1/requirements/${requirement.id}/generate-issue-draft`, async (route) => {
      await route.fulfill({
        status: 202,
        contentType: "application/json",
        body: JSON.stringify({ data: { job_id: "job-issue-github-reconciliation", status: "succeeded" } }),
      });
    });

    await page.route(`**/api/v1/issue-drafts/${pendingIssueDraft.id}`, async (route) => {
      const resolvedIssueDraft = scenario.resolutionAction === "link_existing_issue" ? linkedIssueDraft : approvedIssueDraft;
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: reconciliationResolved ? resolvedIssueDraft : pendingIssueDraft }),
      });
    });

    await page.route(`**/api/v1/issue-drafts/${pendingIssueDraft.id}/resolve-github-reconciliation`, async (route) => {
      const requestBody = route.request().postDataJSON();
      const expectedPayload =
        scenario.resolutionAction === "link_existing_issue"
          ? {
              resolution_action: "link_existing_issue",
              resolution_note: scenario.resolutionNote,
              github_issue_number: expectedGithubIssueNumber,
              github_issue_url: expectedGithubIssueUrl,
            }
          : {
              resolution_action: "approve_retry",
              resolution_note: scenario.resolutionNote,
              resolution_approver: expectedResolutionApprover,
              retry_reason_template: expectedRetryReasonTemplate,
            };
      expect(requestBody).toMatchObject(expectedPayload);

      if (scenario.apiError) {
        await route.fulfill({
          status: scenario.apiError.status,
          contentType: "application/json",
          body: JSON.stringify({
            error: {
              code: scenario.apiError.code,
              message: scenario.apiError.message,
              details: {
                job_id: scenario.apiError.jobId,
                attempt_id: "attempt-github-reconciliation",
              },
            },
            request_id: "playwright-request",
          }),
        });
        return;
      }

      reconciliationResolved = true;
      await route.fulfill({
        status: 202,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            job_id: "job-retry-github-reconciliation",
            status: scenario.resolutionAction === "link_existing_issue" ? "manually_reconciled" : "retry_approved",
            attempt_id: "attempt-github-reconciliation",
            resolution_approver: scenario.resolutionAction === "approve_retry" ? expectedResolutionApprover : undefined,
            retry_reason_template: scenario.resolutionAction === "approve_retry" ? expectedRetryReasonTemplate : undefined,
            github_issue_number: scenario.resolutionAction === "link_existing_issue" ? expectedGithubIssueNumber : undefined,
            github_issue_url: scenario.resolutionAction === "link_existing_issue" ? expectedGithubIssueUrl : undefined,
          },
        }),
      });
    });

    await page.route(`**/api/v1/issue-drafts/${pendingIssueDraft.id}/reconcile-github-publish`, async (route) => {
      const matches = scenario.markerSearchMatches ?? [];
      const searchTotalCount = scenario.markerSearchTotalCount ?? matches.length;
      const searchResultLimit = scenario.markerSearchResultLimit ?? 10;
      await route.fulfill({
        status: 202,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            job_id: "job-marker-github-reconciliation",
            status: matches.length === 1 ? "reconciled" : "review_required",
            attempt_id: "attempt-github-reconciliation",
            match_count: matches.length,
            search_total_count: searchTotalCount,
            search_incomplete_results: scenario.markerSearchIncompleteResults ?? false,
            search_result_limit: searchResultLimit,
            search_has_more_results: searchTotalCount > matches.length,
            review_id: "review-github-reconciliation",
            matches,
            github_issue_number: matches.length === 1 ? matches[0].github_issue_number : undefined,
            github_issue_url: matches.length === 1 ? matches[0].github_issue_url : undefined,
          },
        }),
      });
    });

    await page.route("**/api/v1/jobs/*", async (route) => {
      const jobId = route.request().url().split("/").at(-1);
      const targets: Record<string, { targetType: string; targetId: string; jobType: string }> = {
        "job-minutes-github-reconciliation": { targetType: "minutes", targetId: minutes.id, jobType: "ai_generation" },
        "job-requirement-github-reconciliation": { targetType: "requirement", targetId: requirement.id, jobType: "ai_generation" },
        "job-issue-github-reconciliation": { targetType: "issue_draft", targetId: pendingIssueDraft.id, jobType: "ai_generation" },
        "job-marker-github-reconciliation": { targetType: "issue_draft", targetId: pendingIssueDraft.id, jobType: "github_reconciliation" },
        "job-retry-github-reconciliation": { targetType: "issue_draft", targetId: pendingIssueDraft.id, jobType: "github_reconciliation" },
        "job-link-github-reconciliation-failed": { targetType: "issue_draft", targetId: pendingIssueDraft.id, jobType: "github_reconciliation" },
      };
      const target = targets[jobId ?? ""];
      const failed = jobId === "job-link-github-reconciliation-failed";

      await route.fulfill({
        status: target ? 200 : 404,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            id: jobId,
            project_id: project.id,
            job_type: target?.jobType ?? "ai_generation",
            status: target ? (failed ? "failed" : "succeeded") : "failed",
            target_type: target?.targetType ?? "unknown",
            target_id: target?.targetId,
            progress: 100,
            error_code: failed ? scenario.apiError?.code : undefined,
            safe_error_detail: failed ? scenario.apiError?.message : undefined,
            created_at: now,
            updated_at: now,
          },
        }),
      });
    });

    await page.route(`**/api/v1/minutes/${minutes.id}`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: minutes }) });
    });

    await page.route(`**/api/v1/requirements/${requirement.id}`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: requirement }) });
    });
  }

  async function openPendingGitHubReconciliationDraft(page: Page) {
    await page.goto("/");

    await expect(page.getByRole("button", { name: "Mock GitHub Reconciliation Meeting" })).toBeVisible();
    await page.getByRole("button", { name: "議事録生成", exact: true }).click();
    await expect(page.locator("header").getByText("議事録を生成しました")).toBeVisible();

    await page.getByRole("button", { name: "要件定義を生成", exact: true }).click();
    await expect(page.locator("header").getByText("要件定義を生成しました")).toBeVisible();

    await page.getByRole("button", { name: "Issueドラフトを生成", exact: true }).click();
    await expect(page.locator("header").getByText("Issueドラフトを生成しました")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("公開ブロック")).toBeVisible();
    await expect(
      page.locator("#issue-draft .validation-row.warning").locator("span").filter({ hasText: "GitHub Issueの照合が必要" }),
    ).toBeVisible();
    await expect(page.locator("#issue-draft").getByLabel("GitHub Issue番号")).toHaveValue("42");
    await expect(page.locator("#issue-draft").getByLabel("GitHub Issue URL")).toHaveValue("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42");
    await expect(page.locator("#issue-draft").getByRole("button", { name: "マーカー検索" })).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" })).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "再試行を承認" })).toBeVisible();
  }

  async function expectNoHorizontalLayoutOverflow(page: Page, selector: string) {
    const metrics = await page.locator(selector).evaluate((target) => {
      const element = target as HTMLElement;
      const rect = element.getBoundingClientRect();
      const root = document.documentElement;
      return {
        documentScrollWidth: root.scrollWidth,
        targetClientWidth: element.clientWidth,
        targetLeft: rect.left,
        targetRight: rect.right,
        targetScrollWidth: element.scrollWidth,
        viewportWidth: root.clientWidth,
      };
    });

    expect(metrics.documentScrollWidth).toBeLessThanOrEqual(metrics.viewportWidth + 1);
    expect(metrics.targetLeft).toBeGreaterThanOrEqual(-1);
    expect(metrics.targetRight).toBeLessThanOrEqual(metrics.viewportWidth + 1);
    expect(metrics.targetScrollWidth).toBeLessThanOrEqual(metrics.targetClientWidth + 1);
  }

  test("creates a project, saves a Discord log, generates minutes, and requests review", async ({ page, request }) => {
    await expectApiHealth(request);
    const stamp = Date.now();
    const projectName = `E2E Project ${stamp}`;
    const meetingTitle = `E2E Discord Sync ${stamp}`;
    const rawText = [
      "alice: Decision: connect Playwright smoke coverage.",
      "bob: Open question: who reviews the generated minutes?",
      "alice: Action: request review after minutes are generated.",
    ].join("\n");

    await createProject(page, projectName);

    await saveMeeting(page, meetingTitle, rawText);

    await page.getByRole("button", { name: "議事録生成", exact: true }).click();
    await expect(page.locator("header").getByText("議事録を生成しました")).toBeVisible();
    await expect(page.getByLabel("要約")).toHaveValue(/Playwright smoke coverage/);
    await expect(page.getByLabel("決定事項")).toHaveValue(/connect Playwright smoke coverage/);
    await expect(page.locator("#minutes").getByLabel("未解決事項")).toHaveValue(/who reviews/);
    await expect(page.getByLabel("アクション項目")).toHaveValue(/request review/);

    await page.getByRole("button", { name: "レビュー依頼", exact: true }).click();
    await expect(page.locator("header").getByText("レビューを依頼しました")).toBeVisible();
    await expect(page.getByText("未対応 / Product Manager")).toBeVisible();

    await page.getByRole("button", { name: "議事録を承認", exact: true }).click();
    await expect(page.locator("header").getByText("議事録を承認しました")).toBeVisible();
    await expect(page.locator("#review .panel-header .chip")).toHaveText("通過");

    await page.getByRole("button", { name: "要件定義を生成", exact: true }).click();
    await expect(page.locator("header").getByText("要件定義を生成しました")).toBeVisible();
    await expect(page.getByLabel("背景")).toHaveValue(/Playwright smoke coverage/);
    await expect(page.locator("#requirements").getByRole("textbox", { name: "機能要件", exact: true })).toHaveValue(/connect Playwright smoke coverage/);
    await expect(page.locator("#requirements").getByLabel("未解決事項")).toHaveValue(/who reviews/);

    await page.getByLabel("目的").fill("Updated requirement goal from E2E.");
    await page.locator("#requirements").getByLabel("未解決事項").fill("");
    await page.getByRole("button", { name: "要件定義を保存", exact: true }).click();
    await expect(page.locator("header").getByText("要件定義を保存しました")).toBeVisible();
    await expect(page.getByLabel("目的")).toHaveValue("Updated requirement goal from E2E.");

    await page.getByRole("button", { name: "要件レビュー依頼", exact: true }).click();
    await expect(page.locator("header").getByText("要件レビューを依頼しました")).toBeVisible();
    await expect(page.getByText("未対応 / Product Manager")).toBeVisible();

    await page.getByRole("button", { name: "要件定義を承認", exact: true }).click();
    await expect(page.locator("header").getByText("要件定義を承認しました")).toBeVisible();
    await expect(page.locator("#requirements .panel-header .chip")).toHaveText("承認済み");

    await page.getByRole("button", { name: "Issueドラフトを生成", exact: true }).click();
    await expect(page.locator("header").getByText("Issueドラフトを生成しました")).toBeVisible();
    await expect(page.getByLabel("Issueタイトル")).toHaveValue(/Updated requirement goal from E2E/);
    await expect(page.getByLabel("Issue本文")).toHaveValue(/## Acceptance Criteria/);
    await expect(page.getByLabel("Issue受け入れ条件")).toHaveValue(/connect Playwright smoke coverage/);

    await page.getByLabel("Issueタイトル").fill("Updated issue draft title from E2E.");
    await page.getByRole("button", { name: "Issueドラフトを保存", exact: true }).click();
    await expect(page.locator("header").getByText("Issueドラフトを保存しました")).toBeVisible();
    await expect(page.getByLabel("Issueタイトル")).toHaveValue("Updated issue draft title from E2E.");

    await page.getByRole("button", { name: "Issueドラフトを承認", exact: true }).click();
    await expect(page.locator("header").getByText("Issueドラフトを承認しました")).toBeVisible();
    await expect(page.locator("#issue-draft .panel-header .chip")).toHaveText("承認済み");

    await page.getByRole("button", { name: "OpenAPIドラフトを生成", exact: true }).click();
    await expect(page.locator("header").getByText("OpenAPIドラフトを生成しました")).toBeVisible();
    await expect(page.getByLabel("OpenAPIタイトル")).toHaveValue(/Updated requirement goal from E2E/);
    await expect(page.getByLabel("OpenAPI YAML")).toHaveValue(/openapi: 3.1.0/);
    await expect(page.getByLabel("OpenAPI YAML")).toHaveValue(/paths:/);

    await page.getByLabel("OpenAPIタイトル").fill("Updated OpenAPI draft title from E2E.");
    await page.getByRole("button", { name: "OpenAPIドラフトを保存", exact: true }).click();
    await expect(page.locator("header").getByText("OpenAPIドラフトを保存しました")).toBeVisible();
    await expect(page.getByLabel("OpenAPIタイトル")).toHaveValue("Updated OpenAPI draft title from E2E.");

    await page.getByRole("button", { name: "OpenAPIを検証", exact: true }).click();
    await expect(page.locator("header").getByText("OpenAPI検証に成功しました")).toBeVisible();
    await expect(page.locator("#openapi-draft .panel-header .chip").first()).toHaveText("検証済み");
    await expect(page.locator("#openapi-draft").getByRole("heading", { name: "検証成功" })).toBeVisible();
    await expect(page.locator("#openapi-draft").getByText("missing_error_response")).toBeVisible();

    await page.getByLabel("OpenAPI YAML").fill("openapi: 3.1.0\ninfo:\n  title: Invalid draft\npaths: {}\n");
    await page.getByRole("button", { name: "OpenAPIを検証", exact: true }).click();
    await expect(page.locator("header").getByText("OpenAPI検証に失敗しました")).toBeVisible();
    await expect(page.locator("#openapi-draft").getByRole("heading", { name: "検証失敗" })).toBeVisible();
    await expect(page.locator("#openapi-draft").getByText("empty_paths", { exact: true })).toBeVisible();
    await expect(page.locator("#openapi-draft").getByText("レビューブロッカー")).toBeVisible();
    await expect(page.locator("#openapi-draft .validation-panel", { hasText: "レビューブロッカー" }).locator(".chip")).toHaveText("対応が必要");
    await expect(page.getByText("対応が必要 / OpenAPI Validator")).toBeVisible();

    await page.getByLabel("OpenAPI YAML").fill([
      "openapi: 3.1.0",
      "info:",
      "  title: Valid draft",
      "  version: 0.1.0",
      "paths:",
      "  /drafts:",
      "    post:",
      "      summary: Create draft",
      "      operationId: createDraft",
      "      responses:",
      "        \"201\":",
      "          description: Created",
      "        \"422\":",
      "          description: Validation failed",
      "components:",
      "  schemas:",
      "    DraftResponse:",
      "      type: object",
    ].join("\n"));
    await page.getByRole("button", { name: "OpenAPIを検証", exact: true }).click();
    await expect(page.locator("header").getByText("OpenAPI検証に成功しました")).toBeVisible();
    await expect(page.locator("#openapi-draft").getByRole("heading", { name: "検証成功" })).toBeVisible();
    await expect(page.getByText("解決済み / OpenAPI Validator")).toBeVisible();

    await page.getByRole("button", { name: "GitHub Issueへ公開", exact: true }).click();
    await expect(page.locator("section[role='alert']")).toContainText("GitHub連携が未接続です。");
    await expect(page.locator("#issue-draft").getByText("公開ブロック")).toBeVisible();
    await expect(page.locator("#issue-draft .validation-panel", { hasText: "公開ブロック" }).locator(".chip")).toHaveText("GitHub公開失敗");
    await expect(page.locator("#issue-draft").getByText("照合待ちなし")).toBeVisible();
    await expect(page.locator("#issue-draft").getByLabel("GitHub Issue番号")).toHaveCount(0);
    await expect(page.locator("#issue-draft").getByRole("button", { name: "マーカー検索" })).toHaveCount(0);
    await expect(page.getByLabel("GitHub連携").getByRole("button", { name: "GitHub連携を開始" })).toBeVisible();
    await expect(page.getByLabel("GitHub再接続").getByRole("button", { name: "GitHub連携を開始" })).toBeVisible();
  });

  test("shows validation errors when required meeting fields are missing", async ({ page, request }) => {
    await expectApiHealth(request);
    const stamp = Date.now();

    await createProject(page, `E2E Validation Project ${stamp}`);
    await page.locator("#meeting").getByLabel("タイトル").fill("");
    await page.getByLabel("原文ログ").fill("");
    await page.getByRole("button", { name: "会議を保存" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("入力内容の検証に失敗しました。");
    await expect(page.locator("header").getByText("APIエラー")).toBeVisible();
  });

  test("manages project memberships from the workspace", async ({ page }) => {
    const now = new Date().toISOString();
    const project = {
      id: "project-membership-ui",
      name: "Membership UI Project",
      github_repo: "Kazuya-Sakashita/ai-pm-platform",
      description: "Mocked project for membership UI.",
      status: "active",
      created_at: now,
      updated_at: now,
    };
    const memberships = [
      {
        id: "membership-owner",
        project_id: project.id,
        actor_id: "local-demo-owner",
        role: "owner",
        status: "active",
        created_at: now,
        updated_at: now,
      },
    ];

    await page.route("**/api/v1/operations/queue-health", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            status: "healthy",
            checked_at: now,
            heartbeat_stale_after_seconds: 60,
            oldest_unfinished_threshold_seconds: 300,
            workers: [],
            queues: [],
            failed_executions: { count: 0 },
            failed_job_samples: [],
            recurring_tasks: [],
            product_jobs: { by_status: [], recent_failed_count: 0 },
            warnings: [],
          },
        }),
      });
    });
    await page.route("**/api/v1/projects", async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [project] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/meetings`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/integrations`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/conversation-imports`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [], meta: { total_count: 0 } }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/memberships**`, async (route) => {
      const method = route.request().method();
      if (method === "POST") {
        const requestBody = route.request().postDataJSON();
        const membership = {
          id: "membership-new-reviewer",
          project_id: project.id,
          actor_id: requestBody.actor_id,
          role: requestBody.role,
          status: "active",
          created_at: now,
          updated_at: now,
        };
        memberships.unshift(membership);
        await route.fulfill({ status: 201, contentType: "application/json", body: JSON.stringify({ data: membership }) });
        return;
      }

      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: memberships, meta: { total_count: memberships.length } }),
      });
    });
    await page.route(`**/api/v1/projects/${project.id}/memberships/*`, async (route) => {
      const membershipId = route.request().url().split("/").pop() ?? "";
      const membership = memberships.find((item) => item.id === membershipId);
      if (!membership) {
        await route.fulfill({ status: 404, contentType: "application/json", body: JSON.stringify({ error: { code: "not_found" } }) });
        return;
      }

      if (route.request().method() === "PATCH") {
        const requestBody = route.request().postDataJSON();
        membership.role = requestBody.role;
        membership.updated_at = now;
        await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: membership }) });
        return;
      }

      membership.status = "revoked";
      membership.updated_at = now;
      await route.fulfill({ status: 204 });
    });

    page.on("dialog", (dialog) => dialog.accept());
    await page.goto("/");

    const panel = page.getByLabel("メンバー管理");
    await expect(panel.getByText("local-demo-owner")).toBeVisible();
    await panel.getByLabel("メンバーID").fill("new-reviewer");
    await panel.getByLabel("権限").first().selectOption("viewer");
    await panel.getByRole("button", { name: "メンバー追加" }).click();

    const memberRow = panel.locator(".membership-row").filter({ hasText: "new-reviewer" });
    await expect(memberRow).toBeVisible();
    await memberRow.getByLabel("権限").selectOption("reviewer");
    await expect(memberRow.getByLabel("権限")).toHaveValue("reviewer");
    await memberRow.getByRole("button", { name: "失効" }).click();
    await expect(memberRow.getByText("失効済み")).toBeVisible();
  });

  test("imports, scans, summarizes, and approves a Discord DM paste", async ({ page }) => {
    const now = new Date().toISOString();
    const project = {
      id: "project-discord-dm",
      name: "DM Import Project",
      github_repo: "Kazuya-Sakashita/ai-pm-platform",
      description: "Mocked project for Discord DM import UI.",
      status: "active",
      created_at: now,
      updated_at: now,
    };
    const conversationImportBase = {
      id: "conversation-import-discord-dm",
      project_id: project.id,
      source_type: "discord_dm_paste",
      title: "Discord DM仕様相談",
      raw_text: "依頼者: 決定: DM整理MVPを作る。\nPM: 対応: 同意確認を記録する。",
      redacted_text: "依頼者: 決定: DM整理MVPを作る。\nPM: 対応: 同意確認を記録する。",
      participants: [
        { display_name: "依頼者", role: "requester" },
        { display_name: "PM", role: "responder" },
      ],
      consent_confirmed: true,
      consent_statement_version: "discord-dm-manual-import-v1",
      safety_flags: [],
      blocked_reasons: [],
      raw_text_retention_expires_at: now,
      retention_expires_at: now,
      created_at: now,
      updated_at: now,
    };
    const summaryDraft = {
      id: "conversation-summary-draft-discord-dm",
      conversation_import_id: conversationImportBase.id,
      status: "draft",
      summary: "DMから手動インポートMVPと同意確認の必要性を整理した。",
      decisions: [{ text: "Discord DM整理MVPを手動貼り付けで進める。", confidence: 0.92 }],
      open_questions: ["マスキング確認者をどこに記録するか。"],
      action_items: [{ text: "同意確認をAuditLogに残す。", status: "open", confidence: 0.88 }],
      issue_candidates: [
        {
          title: "DM手動インポートUIを追加",
          body: "同意確認、マスキング、安全チェック、整理ドラフト承認をUIで扱う。",
          labels: ["discord", "dm"],
          priority: "P1",
          confidence: 0.86,
        },
      ],
      requirement_candidates: [
        {
          title: "DM整理レビューゲート",
          requirement: "DM由来の整理結果は人間承認後に下流へ渡す。",
          acceptance_criteria: ["承認理由なしでは承認できない。"],
          confidence: 0.84,
        },
      ],
      risks: [{ text: "相手方同意なしの取り込み。", severity: "high", mitigation: "同意チェックを必須にする。", confidence: 0.9 }],
      participants: conversationImportBase.participants,
      source_quotes: [{ id: "quote-1", quote: "決定: DM整理MVPを作る。", speaker: "依頼者" }],
      confidence: 0.89,
      generated_by_model: "deterministic-conversation-summary-v1",
      created_at: now,
      updated_at: now,
    };
    let latestSummaryDraft: typeof summaryDraft | undefined;

    await page.route("**/api/v1/operations/queue-health", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            status: "healthy",
            checked_at: now,
            heartbeat_stale_after_seconds: 60,
            oldest_unfinished_threshold_seconds: 300,
            workers: [],
            queues: [],
            failed_executions: { count: 0 },
            failed_job_samples: [],
            recurring_tasks: [],
            product_jobs: {
              by_status: [],
              recent_failed_count: 0,
            },
            warnings: [],
          },
        }),
      });
    });
    await page.route("**/api/v1/projects", async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [project] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/meetings`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/integrations`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/memberships**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: [
            {
              id: "membership-local-demo-owner",
              project_id: project.id,
              actor_id: "local-demo-owner",
              role: "owner",
              status: "active",
              created_at: now,
              updated_at: now,
            },
          ],
          meta: { total_count: 1 },
        }),
      });
    });
    await page.route(`**/api/v1/projects/${project.id}/conversation-imports`, async (route) => {
      if (route.request().method() === "POST") {
        const requestBody = route.request().postDataJSON();
        expect(requestBody).toMatchObject({
          source_type: "discord_dm_paste",
          title: "Discord DM整理E2E",
          consent_confirmed: true,
          consent_statement_version: "discord-dm-manual-import-v1",
          redacted_text: "依頼者: 決定: DM整理MVPを作る。\nPM: 対応: 同意確認を記録する。",
        });
        expect(requestBody.participants).toEqual([
          { display_name: "依頼者", role: "unknown" },
          { display_name: "PM", role: "unknown" },
        ]);

        await route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({ data: { ...conversationImportBase, title: requestBody.title } }),
        });
        return;
      }

      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [], meta: { total_count: 0 } }) });
    });
    await page.route(`**/api/v1/conversation-imports/${conversationImportBase.id}`, async (route) => {
      if (route.request().method() === "DELETE") {
        await route.fulfill({ status: 204 });
        return;
      }

      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            ...conversationImportBase,
            title: "Discord DM整理E2E",
            status: latestSummaryDraft?.status === "approved" ? "approved" : latestSummaryDraft ? "summary_draft" : "ready_for_ai",
            latest_summary_draft: latestSummaryDraft,
          },
        }),
      });
    });
    await page.route(`**/api/v1/conversation-imports/${conversationImportBase.id}/scan`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            valid: true,
            conversation_import: { ...conversationImportBase, title: "Discord DM整理E2E", status: "ready_for_ai" },
            safety_flags: [],
            blocked_reasons: [],
            redaction_suggestions: [],
            next_action: "generate_summary",
          },
        }),
      });
    });
    await page.route(`**/api/v1/conversation-imports/${conversationImportBase.id}/generate-summary`, async (route) => {
      latestSummaryDraft = summaryDraft;
      await route.fulfill({
        status: 202,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            job: {
              id: "job-conversation-summary",
              project_id: project.id,
              job_type: "ai_generation",
              status: "succeeded",
              target_type: "conversation_summary_draft",
              target_id: summaryDraft.id,
              progress: 100,
              created_at: now,
              updated_at: now,
            },
            conversation_summary_draft: summaryDraft,
          },
        }),
      });
    });
    await page.route(`**/api/v1/conversation-summary-drafts/${summaryDraft.id}/approve`, async (route) => {
      const requestBody = route.request().postDataJSON();
      expect(requestBody).toMatchObject({
        approval_note: "同意確認とマスキング内容をレビューしました。",
        generate_downstream_candidates: true,
      });
      latestSummaryDraft = { ...summaryDraft, status: "approved" };
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: latestSummaryDraft }) });
    });

    await page.goto("/");
    await expect(page.getByRole("heading", { name: "DM Import Project" })).toBeVisible();
    await expect(page.locator("#conversation-import").getByRole("heading", { name: "手動インポート" })).toBeVisible();

    await page.locator("#conversation-import").getByLabel("DMタイトル").fill("Discord DM整理E2E");
    await page.locator("#conversation-import").getByLabel("参加者").fill("依頼者, PM");
    await page.locator("#conversation-import").getByLabel("DM原文").fill(conversationImportBase.raw_text);
    await page.locator("#conversation-import").getByLabel("マスキング後テキスト").fill(conversationImportBase.redacted_text);
    await page.locator("#conversation-import").getByLabel("取り込み権限と相手方同意を確認済み").check();

    await page.locator("#conversation-import").getByRole("button", { name: "DMインポートを保存" }).click();
    await expect(page.locator("header").getByText("DMインポートを保存しました")).toBeVisible();
    await expect(page.locator("#conversation-import").getByText("保存状態")).toBeVisible();

    await page.locator("#conversation-import").getByRole("button", { name: "安全チェック" }).click();
    await expect(page.locator("header").getByText("DMの安全チェックに合格しました")).toBeVisible();
    await expect(page.locator("#conversation-import > .panel-header .chip")).toHaveText("AI整理可能");

    await page.locator("#conversation-import").getByRole("button", { name: "整理ドラフト生成" }).click();
    await expect(page.locator("header").getByText("DM整理ドラフトを生成しました")).toBeVisible();
    await expect(page.locator("header").getByText("ジョブ 完了")).toBeVisible();
    await expect(page.locator("#conversation-import").getByLabel("整理要約")).toHaveValue(/DMから手動インポートMVP/);
    await expect(page.locator("#conversation-import").getByLabel("決定事項")).toHaveValue(/手動貼り付けで進める/);
    await expect(page.locator("#conversation-import").getByText("DM手動インポートUIを追加")).toBeVisible();
    await expect(page.locator("#conversation-import").getByText("DM整理レビューゲート")).toBeVisible();

    await page.locator("#conversation-import").getByRole("button", { name: "整理ドラフト承認" }).click();
    await expect(page.locator("header").getByText("DM整理ドラフトを承認しました")).toBeVisible();
    await expect(page.locator("#conversation-import .validation-panel.success .chip").first()).toHaveText("承認済み");
    await expect(page.getByLabel("DMインポート一覧").getByText("承認済み")).toBeVisible();

    page.once("dialog", async (dialog) => {
      expect(dialog.message()).toContain("DMインポートを匿名化");
      await dialog.accept();
    });
    await page.locator("#conversation-import").getByRole("button", { name: "DM匿名化" }).click();
    await expect(page.locator("header").getByText("DMインポートを匿名化しました")).toBeVisible();
    await expect(page.getByLabel("DMインポート一覧").getByText("DMインポートなし")).toBeVisible();
  });

  test("shows safe PII redaction suggestions before Discord DM summary generation", async ({ page }) => {
    const now = new Date().toISOString();
    const project = {
      id: "project-discord-dm-pii",
      name: "DM PII Project",
      github_repo: "Kazuya-Sakashita/ai-pm-platform",
      description: "Mocked project for PII redaction UI.",
      status: "active",
      created_at: now,
      updated_at: now,
    };
    const conversationImport = {
      id: "conversation-import-discord-dm-pii",
      project_id: project.id,
      source_type: "discord_dm_paste",
      title: "PIIを含むDM相談",
      raw_text: "連絡先は customer@example.com と 090-1234-5678 です。",
      redacted_text: "連絡先は未マスキングです。",
      participants: [{ display_name: "依頼者", role: "requester" }],
      consent_confirmed: true,
      consent_statement_version: "discord-dm-manual-import-v1",
      status: "draft",
      safety_flags: [],
      blocked_reasons: [],
      raw_text_retention_expires_at: now,
      retention_expires_at: now,
      created_at: now,
      updated_at: now,
    };

    await page.route("**/api/v1/operations/queue-health", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            status: "healthy",
            checked_at: now,
            heartbeat_stale_after_seconds: 60,
            oldest_unfinished_threshold_seconds: 300,
            workers: [],
            queues: [],
            failed_executions: { count: 0 },
            failed_job_samples: [],
            recurring_tasks: [],
            product_jobs: { by_status: [], recent_failed_count: 0 },
            warnings: [],
          },
        }),
      });
    });
    await page.route("**/api/v1/projects", async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [project] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/meetings`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/integrations`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });
    await page.route(`**/api/v1/projects/${project.id}/memberships**`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: [
            {
              id: "membership-local-demo-owner",
              project_id: project.id,
              actor_id: "local-demo-owner",
              role: "owner",
              status: "active",
              created_at: now,
              updated_at: now,
            },
          ],
          meta: { total_count: 1 },
        }),
      });
    });
    await page.route(`**/api/v1/projects/${project.id}/conversation-imports`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: [conversationImport], meta: { total_count: 1 } }),
      });
    });
    await page.route(`**/api/v1/conversation-imports/${conversationImport.id}/scan`, async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            valid: false,
            conversation_import: { ...conversationImport, status: "blocked" },
            safety_flags: [
              {
                type: "personal_data",
                severity: "high",
                action: "blocked",
                location_hint: "メールアドレス",
                message: "メールアドレスの可能性があります。AI整理前に個人を特定できない表現へ置換してください。",
              },
              {
                type: "personal_data",
                severity: "high",
                action: "blocked",
                location_hint: "電話番号",
                message: "電話番号の可能性があります。AI整理前に連絡先を伏字化してください。",
              },
            ],
            blocked_reasons: ["personal_data_blocked"],
            redaction_suggestions: [
              {
                location_hint: "メールアドレス",
                reason: "メールアドレスの可能性があります。AI整理前に個人を特定できない表現へ置換してください。",
                suggested_replacement: "[EMAIL_REDACTED]",
              },
              {
                location_hint: "電話番号",
                reason: "電話番号の可能性があります。AI整理前に連絡先を伏字化してください。",
                suggested_replacement: "[PHONE_REDACTED]",
              },
            ],
            next_action: "edit_and_rescan",
          },
        }),
      });
    });

    await page.goto("/");
    await expect(page.getByRole("heading", { name: "DM PII Project" })).toBeVisible();
    await page.getByLabel("DMインポート一覧").getByText("PIIを含むDM相談").click();
    await page.locator("#conversation-import").getByRole("button", { name: "安全チェック" }).click();
    await expect(page.locator("header").getByText("DMの安全チェックで修正が必要です")).toBeVisible();

    const safetyPanel = page.locator("#conversation-import .validation-panel", { hasText: "安全チェック結果" });
    await expect(safetyPanel).toContainText("個人情報");
    await expect(safetyPanel).toContainText("メールアドレス");
    await expect(safetyPanel).toContainText("[EMAIL_REDACTED]");
    await expect(safetyPanel).toContainText("電話番号");
    await expect(safetyPanel).toContainText("[PHONE_REDACTED]");
    await expect(safetyPanel).not.toContainText("customer@example.com");
    await expect(safetyPanel).not.toContainText("090-1234-5678");
    await expect(page.locator("#conversation-import").getByRole("button", { name: "整理ドラフト生成" })).toBeDisabled();
  });

  test("does not call DELETE when DM anonymization confirmation is cancelled", async ({ page }) => {
    const scenario = await mockExistingDmImportForAnonymization(page);

    page.once("dialog", async (dialog) => {
      expect(dialog.message()).toContain("DMインポートを匿名化");
      await dialog.dismiss();
    });

    await page.locator("#conversation-import").getByRole("button", { name: "DM匿名化" }).click();

    expect(scenario.deleteRequestCount()).toBe(0);
    await expect(page.locator("header").getByText("DMインポートを匿名化しました")).toHaveCount(0);
    await expect(page.getByLabel("DMインポート一覧").getByText(scenario.conversationImport.title)).toBeVisible();
    await expect(page.locator("#conversation-import").getByRole("button", { name: "DM匿名化" })).toBeEnabled();
  });

  test("shows a safe Japanese error when DM anonymization fails", async ({ page }) => {
    const scenario = await mockExistingDmImportForAnonymization(page, {
      deleteFailure: {
        status: 500,
        code: "conversation_import_anonymization_failed",
        message: "Conversation import anonymization failed.",
        expectedMessage: "DMインポートの匿名化に失敗しました。",
      },
    });

    page.once("dialog", async (dialog) => {
      await dialog.accept();
    });
    await page.locator("#conversation-import").getByRole("button", { name: "DM匿名化" }).click();

    expect(scenario.deleteRequestCount()).toBe(1);
    await expect(page.locator("header").getByText("APIエラー")).toBeVisible();
    await expect(page.locator("section[role='alert']")).toContainText("DMインポートの匿名化に失敗しました。");
    await expect(page.getByLabel("DMインポート一覧").getByText(scenario.conversationImport.title)).toBeVisible();
  });

  for (const failure of [
    {
      status: 403,
      code: "conversation_import_forbidden",
      message: "Conversation import access is forbidden.",
      expectedMessage: "DMインポートを操作する権限がありません。",
    },
    {
      status: 422,
      code: "conversation_import_anonymized",
      message: "Conversation import has been anonymized.",
      expectedMessage: "DMインポートは匿名化済みです。",
    },
  ] satisfies DmAnonymizationFailure[]) {
    test(`shows safe Japanese copy for DM anonymization ${failure.status} errors`, async ({ page }) => {
      const scenario = await mockExistingDmImportForAnonymization(page, { deleteFailure: failure });

      page.once("dialog", async (dialog) => {
        await dialog.accept();
      });
      await page.locator("#conversation-import").getByRole("button", { name: "DM匿名化" }).click();

      expect(scenario.deleteRequestCount()).toBe(1);
      await expect(page.locator("header").getByText("APIエラー")).toBeVisible();
      await expect(page.locator("section[role='alert']")).toContainText(failure.expectedMessage);
      await expect(page.getByLabel("DMインポート一覧").getByText(scenario.conversationImport.title)).toBeVisible();
    });
  }

  test("keeps DM anonymization controls and retention audit readable on mobile", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 });
    await mockExistingDmImportForAnonymization(page);

    const panel = page.locator("#conversation-import");
    const anonymizeButton = panel.getByRole("button", { name: "DM匿名化" });
    const auditBox = panel.locator(".conversation-audit");

    await anonymizeButton.scrollIntoViewIfNeeded();
    await expect(anonymizeButton).toBeVisible();
    await auditBox.scrollIntoViewIfNeeded();
    await expect(auditBox.locator("strong", { hasText: "原文期限" })).toBeVisible();
    await expect(auditBox.locator("strong", { hasText: "本文期限" })).toBeVisible();
    await expect(auditBox.locator("strong", { hasText: "匿名化" })).toBeVisible();

    const buttonBox = await anonymizeButton.boundingBox();
    const auditBoxBounds = await auditBox.boundingBox();
    expect(buttonBox).not.toBeNull();
    expect(auditBoxBounds).not.toBeNull();

    const overlaps =
      buttonBox !== null &&
      auditBoxBounds !== null &&
      buttonBox.x < auditBoxBounds.x + auditBoxBounds.width &&
      buttonBox.x + buttonBox.width > auditBoxBounds.x &&
      buttonBox.y < auditBoxBounds.y + auditBoxBounds.height &&
      buttonBox.y + buttonBox.height > auditBoxBounds.y;

    expect(overlaps).toBe(false);
  });

  test("shows pending GitHub reconciliation controls and approves a controlled retry", async ({ page }) => {
    await mockPendingGitHubReconciliationWorkflow(page);
    await openPendingGitHubReconciliationDraft(page);

    await expect(page.locator("#issue-draft").getByRole("heading", { name: "照合履歴" })).toBeVisible();
    await expect(
      page.getByLabel("GitHub公開照合履歴").getByText("GitHub Issueが作成済みの可能性があります。照合が必要です。").first(),
    ).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("GitHub連携が未接続です。")).toBeVisible();
    await expect(page.locator("#issue-draft").getByLabel("再試行理由")).toHaveValue("github_issue_absence_confirmed");
    await page.locator("#issue-draft").getByLabel("解決メモ").fill("Confirmed that no GitHub Issue exists.");
    await page.locator("#issue-draft").getByRole("button", { name: "再試行を承認" }).click();

    await expect(page.locator("header").getByText("APIエラー")).toBeVisible();
    await expect(page.locator("section[role='alert']")).toContainText("再試行の承認者を入力してください。");

    await page.locator("#issue-draft").getByLabel("再試行承認者").fill("Kazuya Reviewer");
    await page.locator("#issue-draft").getByLabel("再試行理由").selectOption("github_issue_absence_confirmed");
    await page.locator("#issue-draft").getByRole("button", { name: "再試行を承認" }).click();

    await expect(page.locator("header").getByText("GitHub公開の再試行を承認しました")).toBeVisible();
    await expect(page.locator("#issue-draft > .panel-header .chip")).toHaveText("承認済み");
    await expect(page.locator("#issue-draft").getByText("再試行承認済み")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("承認者 Kazuya Reviewer")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("GitHub上でIssue未作成を確認したため1回だけ再試行を承認します。")).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "再試行を承認" })).toHaveCount(0);
  });

  test("shows GitHub reconciliation cooldown and disables risky retry actions", async ({ page }) => {
    const nextRetryAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();
    await mockPendingGitHubReconciliationWorkflow(page, {
      resolutionAction: "approve_retry",
      resolutionNote: "Confirmed that no GitHub Issue exists.",
      reconciliationRetryCount: 1,
      nextReconciliationRetryAt: nextRetryAt,
    });
    await openPendingGitHubReconciliationDraft(page);

    await expect(page.locator("#issue-draft").getByText("再検索回数 1回")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("次の再検索")).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "マーカー検索" })).toBeDisabled();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "再試行を承認" })).toBeDisabled();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" })).toBeEnabled();
  });

  test("links an existing GitHub Issue from pending reconciliation", async ({ page }) => {
    await mockPendingGitHubReconciliationWorkflow(page, {
      resolutionAction: "link_existing_issue",
      resolutionNote: "Reviewed duplicates and selected the canonical Issue.",
    });
    await openPendingGitHubReconciliationDraft(page);

    await page.locator("#issue-draft").getByLabel("解決メモ").fill("Reviewed duplicates and selected the canonical Issue.");
    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("header").getByText("GitHub Issueに紐付けました")).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("heading", { name: "公開済みGitHub Issue", exact: true })).toBeVisible();
    await expect(
      page
        .locator("#issue-draft .validation-panel.success")
        .getByRole("link", { name: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42" }),
    ).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("照合済み")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("公開ブロック")).toHaveCount(0);
    await expect(page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" })).toHaveCount(0);
  });

  test("selects a GitHub Issue candidate from marker search results", async ({ page }) => {
    await mockPendingGitHubReconciliationWorkflow(page, {
      resolutionAction: "link_existing_issue",
      resolutionNote: "マーカー検索候補 #43 を選択しました。",
      expectedGithubIssueNumber: 43,
      expectedGithubIssueUrl: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43",
      markerSearchTotalCount: 24,
      markerSearchIncompleteResults: true,
      markerSearchMatches: [
        {
          github_issue_number: 42,
          github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
          github_repository: "Kazuya-Sakashita/ai-pm-platform",
          github_issue_title: "Candidate Issue A",
          github_issue_state: "open",
          github_issue_updated_at: "2026-07-02T01:23:45Z",
          github_issue_score: 12.7,
          github_issue_api_id: 420,
          github_issue_node_id: "I_kwCANDIDATE_42",
        },
        {
          github_issue_number: 43,
          github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43",
          github_repository: "Kazuya-Sakashita/ai-pm-platform",
          github_issue_title: "Candidate Issue B",
          github_issue_state: "closed",
          github_issue_updated_at: "2026-07-02T02:34:56Z",
          github_issue_score: 18.8,
          github_issue_api_id: 430,
          github_issue_node_id: "I_kwCANDIDATE_43",
        },
      ],
    });
    await openPendingGitHubReconciliationDraft(page);

    await page.locator("#issue-draft").getByRole("button", { name: "マーカー検索" }).click();

    await expect(page.locator("header").getByText("GitHub公開の照合に確認が必要です")).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("heading", { name: "候補Issue" })).toBeVisible();
    await expect(page.getByLabel("GitHub Issue候補").getByText("2件")).toBeVisible();
    await expect(page.getByLabel("GitHub Issue候補").getByText("検索総数 24件")).toBeVisible();
    await expect(page.getByLabel("GitHub Issue候補").getByText("上位10件のみ表示")).toBeVisible();
    await expect(page.getByLabel("GitHub Issue候補").getByText("検索未完了")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("#43 Candidate Issue B")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText(/状態 クローズ .* スコア 18.8/)).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43")).toBeVisible();

    const candidate = page.locator("#issue-draft .candidate-row", { hasText: "#43" });
    await expect(candidate).not.toHaveAttribute("aria-current", "true");
    await expect(candidate.getByRole("button", { name: "候補を選択" })).toHaveAttribute("aria-pressed", "false");
    await page.locator("#issue-draft").getByRole("button", { name: "マーカー検索" }).focus();
    await page.keyboard.press("Shift+Tab");
    await expect(candidate.getByRole("button", { name: "候補を選択" })).toBeFocused();
    await page.keyboard.press("Enter");

    await expect(page.locator("header").getByText("GitHub Issue #43 を候補として選択しました")).toBeVisible();
    await expect(candidate).toHaveAttribute("aria-current", "true");
    await expect(candidate.getByRole("button", { name: "選択中" })).toHaveAttribute("aria-pressed", "true");
    await expect(candidate.locator(".chip.success")).toHaveText("選択中");
    await expect(page.locator("#issue-draft").getByLabel("GitHub Issue番号")).toHaveValue("43");
    await expect(page.locator("#issue-draft").getByRole("textbox", { name: "GitHub Issue URL", exact: true })).toHaveValue(
      "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43",
    );
    await expect(page.locator("#issue-draft").getByLabel("解決メモ")).toHaveValue("マーカー検索候補 #43 を選択しました。");

    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("header").getByText("GitHub Issueに紐付けました")).toBeVisible();
    await expect(
      page
        .locator("#issue-draft .validation-panel.success")
        .getByRole("link", { name: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43" }),
    ).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("公開ブロック")).toHaveCount(0);
  });

  test("keeps long GitHub Issue candidate title and URL inside the narrow layout", async ({ page }) => {
    await page.setViewportSize({ width: 390, height: 900 });
    const longTitle =
      "Candidate Issue with a very long title " +
      "AIProjectManagerReconciliationCandidateWithoutNaturalBreaks".repeat(4);
    const longUrl = `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/444#${"ai-pm-platform-reconciliation-marker".repeat(6)}`;

    await mockPendingGitHubReconciliationWorkflow(page, {
      resolutionAction: "link_existing_issue",
      resolutionNote: "Long candidate layout review.",
      markerSearchMatches: [
        {
          github_issue_number: 444,
          github_issue_url: longUrl,
          github_repository: "Kazuya-Sakashita/ai-pm-platform",
          github_issue_title: longTitle,
          github_issue_state: "open",
          github_issue_updated_at: "2026-07-02T03:45:00Z",
          github_issue_score: 24.4,
          github_issue_api_id: 4440,
          github_issue_node_id: "I_kwLONG_444",
        },
        {
          github_issue_number: 445,
          github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/445",
          github_repository: "Kazuya-Sakashita/ai-pm-platform",
          github_issue_title: "Secondary candidate",
          github_issue_state: "closed",
          github_issue_updated_at: "2026-07-02T04:45:00Z",
          github_issue_score: 13.2,
          github_issue_api_id: 4450,
          github_issue_node_id: "I_kwLONG_445",
        },
      ],
    });
    await openPendingGitHubReconciliationDraft(page);

    await page.locator("#issue-draft").getByRole("button", { name: "マーカー検索" }).click();

    const candidate = page.locator("#issue-draft .candidate-row", { hasText: "#444" });
    await expect(candidate).toBeVisible();
    await expect(candidate.getByText(longTitle)).toBeVisible();
    await expect(candidate.getByText(longUrl)).toBeVisible();
    await expect(candidate.getByRole("button", { name: "候補を選択" })).toBeVisible();

    await expectNoHorizontalLayoutOverflow(page, "#issue-draft");
    await expectNoHorizontalLayoutOverflow(page, "#issue-draft .reconciliation-candidates");
    await expectNoHorizontalLayoutOverflow(page, "#issue-draft .candidate-list .candidate-row:first-child");
  });

  test("keeps ten GitHub Issue candidates scannable and selectable", async ({ page }) => {
    const matches = Array.from({ length: 10 }, (_, index) => {
      const issueNumber = 500 + index;
      return {
        github_issue_number: issueNumber,
        github_issue_url: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/${issueNumber}`,
        github_repository: "Kazuya-Sakashita/ai-pm-platform",
        github_issue_title: `Ranked candidate ${index + 1}`,
        github_issue_state: index % 2 === 0 ? "open" : "closed",
        github_issue_updated_at: `2026-07-02T${String(index).padStart(2, "0")}:00:00Z`,
        github_issue_score: 30 - index,
        github_issue_api_id: 5000 + index,
        github_issue_node_id: `I_kwTEN_${issueNumber}`,
      } satisfies ReconciliationMatch;
    });

    await mockPendingGitHubReconciliationWorkflow(page, {
      resolutionAction: "link_existing_issue",
      resolutionNote: "マーカー検索候補 #509 を選択しました。",
      expectedGithubIssueNumber: 509,
      expectedGithubIssueUrl: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/509",
      markerSearchMatches: matches,
      markerSearchTotalCount: 24,
      markerSearchResultLimit: 10,
    });
    await openPendingGitHubReconciliationDraft(page);

    await page.locator("#issue-draft").getByRole("button", { name: "マーカー検索" }).click();

    await expect(page.locator("#issue-draft").getByText("10件", { exact: true })).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("検索総数 24件")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("上位10件のみ表示")).toBeVisible();
    await expect(page.locator("#issue-draft .candidate-row")).toHaveCount(10);

    const finalCandidate = page.locator("#issue-draft .candidate-row", { hasText: "#509" });
    await finalCandidate.scrollIntoViewIfNeeded();
    await expect(finalCandidate.getByText("Ranked candidate 10")).toBeVisible();
    await expect(finalCandidate.getByText(/状態 クローズ .* スコア 21/)).toBeVisible();
    await expect(finalCandidate.getByRole("button", { name: "候補を選択" })).toBeVisible();
    await expectNoHorizontalLayoutOverflow(page, "#issue-draft .reconciliation-candidates");
    await expectNoHorizontalLayoutOverflow(page, "#issue-draft .candidate-list .candidate-row:last-child");

    await finalCandidate.getByRole("button", { name: "候補を選択" }).click();

    await expect(finalCandidate).toHaveAttribute("aria-current", "true");
    await expect(finalCandidate.getByRole("button", { name: "選択中" })).toHaveAttribute("aria-pressed", "true");
    await expect(page.locator("#issue-draft").getByLabel("GitHub Issue番号")).toHaveValue("509");
    await expect(page.locator("#issue-draft").getByRole("textbox", { name: "GitHub Issue URL", exact: true })).toHaveValue(
      "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/509",
    );
  });

  test("shows validation errors before linking an existing GitHub Issue", async ({ page }) => {
    await mockPendingGitHubReconciliationWorkflow(page, {
      resolutionAction: "link_existing_issue",
      resolutionNote: "Validate manual link input before submitting.",
    });
    await openPendingGitHubReconciliationDraft(page);

    await page.locator("#issue-draft").getByLabel("解決メモ").fill("Validate manual link input before submitting.");
    await page.locator("#issue-draft").getByLabel("GitHub Issue番号").fill("0");
    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("GitHub Issue番号は1以上の整数で入力してください。");
    await expect(page.locator("header").getByText("GitHub Issueに紐付けました")).toHaveCount(0);

    await page.locator("#issue-draft").getByLabel("GitHub Issue番号").fill("42");
    await page.locator("#issue-draft").getByLabel("GitHub Issue URL").fill("");
    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("GitHub Issue URLを入力してください。");
    await expect(page.locator("#issue-draft").getByText("公開ブロック")).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" })).toBeVisible();

    await page.locator("#issue-draft").getByRole("textbox", { name: "GitHub Issue URL", exact: true }).fill("https://example.com/issues/42");
    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("GitHub Issue URLはgithub.comのIssue URLを入力してください。");

    await page
      .locator("#issue-draft")
      .getByRole("textbox", { name: "GitHub Issue URL", exact: true })
      .fill("http://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42");
    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("GitHub Issue URLはhttpsのGitHub Issue URLで入力してください。");
    await expect(page.locator("header").getByText("GitHub Issueに紐付けました")).toHaveCount(0);

    await page
      .locator("#issue-draft")
      .getByRole("textbox", { name: "GitHub Issue URL", exact: true })
      .fill("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/43");
    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("GitHub Issue URLはIssue番号と一致している必要があります。");
    await expect(page.locator("#issue-draft").getByText("公開ブロック")).toBeVisible();
  });

  test("shows repository validation errors before linking a GitHub Issue from another repository", async ({ page }) => {
    await mockPendingGitHubReconciliationWorkflow(page, {
      resolutionAction: "link_existing_issue",
      resolutionNote: "Reject a GitHub Issue URL from another repository.",
      expectedGithubIssueUrl: "https://github.com/Other/repo/issues/42",
    });
    await openPendingGitHubReconciliationDraft(page);

    await page.locator("#issue-draft").getByLabel("解決メモ").fill("Reject a GitHub Issue URL from another repository.");
    await page.locator("#issue-draft").getByRole("textbox", { name: "GitHub Issue URL", exact: true }).fill("https://github.com/Other/repo/issues/42");
    await page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("GitHub Issue URLはプロジェクトのリポジトリとIssue番号に一致している必要があります。");
    await expect(page.locator("header").getByText("APIエラー")).toBeVisible();
    await expect(page.locator("#issue-draft").getByText("公開ブロック")).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("button", { name: "既存Issueに紐付け" })).toBeVisible();
    await expect(page.locator("#issue-draft").getByRole("heading", { name: "公開済みGitHub Issue", exact: true })).toHaveCount(0);
  });

  test("blocks secret-like content and surfaces the failed generation job", async ({ page, request }) => {
    await expectApiHealth(request);
    const stamp = Date.now();
    const meetingTitle = `E2E Secret Block ${stamp}`;

    await createProject(page, `E2E Secret Project ${stamp}`);
    await saveMeeting(page, meetingTitle, "alice: password=super-secret-value");

    await page.getByRole("button", { name: "議事録生成", exact: true }).click();

    await expect(page.locator("section[role='alert']")).toContainText("会議ログに機密性の高い内容");
    await expect(page.locator("header").getByText("ジョブ 失敗")).toBeVisible();
    await expect(page.locator("#review").getByText("議事録生成")).toBeVisible();
    await expect(page.locator("#review").getByText("いいえ")).toHaveCount(6);
  });

  for (const failure of providerFailures) {
    test(`surfaces ${failure.name} as a failed generation job`, async ({ page, request }) => {
      await expectApiHealth(request);
      const stamp = Date.now();
      const meetingTitle = `E2E ${failure.name} ${stamp}`;

      await createProject(page, `E2E Provider Failure Project ${stamp}`);
      await saveMeeting(page, meetingTitle, "alice: Decision: keep AI failures visible and recoverable.");
      await mockGenerationFailure(page, failure);

      await page.getByRole("button", { name: "議事録生成", exact: true }).click();

      await expect(page.locator("section[role='alert']")).toContainText(failure.expectedMessage);
      await expect(page.locator("header").getByText("APIエラー")).toBeVisible();
      await expect(page.locator("header").getByText("ジョブ 失敗")).toBeVisible();
      await expect(page.getByText("失敗 / 議事録")).toBeVisible();
      await expect(page.locator("#review").getByText("議事録生成")).toBeVisible();
      await expect(page.locator("#review").getByText("いいえ")).toHaveCount(6);
    });
  }
});
