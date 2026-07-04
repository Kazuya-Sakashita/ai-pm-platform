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
    await expect(page.getByRole("button", { name: new RegExp(meetingTitle) })).toBeVisible();
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
    await expect(page.locator("#issue-draft").getByRole("heading", { name: "GitHub Issue", exact: true })).toBeVisible();
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
    await expect(page.locator("#issue-draft").getByRole("heading", { name: "GitHub Issue", exact: true })).toHaveCount(0);
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
