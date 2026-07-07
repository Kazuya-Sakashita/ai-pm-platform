import { expect, test } from "@playwright/test";

test.describe("Queue health operations panel", () => {
  test("shows queue health summary and refreshes it manually", async ({ page }) => {
    const now = new Date().toISOString();
    const project = {
      id: "project-queue-health",
      name: "Queue Health Project",
      github_repo: "Kazuya-Sakashita/ai-pm-platform",
      description: "Mocked project for queue health panel.",
      status: "active",
      created_at: now,
      updated_at: now,
    };
    let queueHealthRequests = 0;
    let operationRequests = 0;
    const projectId = project.id;

    await page.route("**/api/v1/projects", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ data: [project] }),
      });
    });

    await page.route(`**/api/v1/projects/${project.id}/meetings`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });

    await page.route(`**/api/v1/projects/${project.id}/integrations`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });

    await page.route(`**/api/v1/projects/${project.id}/memberships**`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [], meta: { total_count: 0 } }) });
    });

    await page.route(`**/api/v1/projects/${project.id}/conversation-imports**`, async (route) => {
      await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [] }) });
    });

    await page.route("**/api/v1/operations/queue-health**", async (route) => {
      queueHealthRequests += 1;
      const healthy = queueHealthRequests > 1;

      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            status: healthy ? "healthy" : "degraded",
            checked_at: now,
            heartbeat_stale_after_seconds: 60,
            oldest_unfinished_threshold_seconds: 300,
            workers: healthy
              ? [{ kind: "worker", name: "worker-1", hostname: "queue-host", last_heartbeat_at: now, stale: false }]
              : [{ kind: "worker", name: "worker-1", hostname: "queue-host", last_heartbeat_at: now, stale: true }],
            queues: [
              {
                queue_name: "default",
                unfinished_count: healthy ? 0 : 2,
                oldest_unfinished_at: now,
                oldest_unfinished_age_seconds: healthy ? 0 : 420,
              },
            ],
            failed_executions: { count: healthy ? 0 : 1, latest_failed_at: healthy ? undefined : now },
            failed_job_samples: healthy
              ? []
              : [
                  {
                    failed_job_id: 456,
                    job_id: 123,
                    product_job_id: "18b92270-8f9f-45cb-a8d0-6f7442ce8241",
                    project_id: projectId,
                    project_boundary_status: "verified",
                    product_job_mapping_source: "explicit",
                    queue_name: "github_reconciliation",
                    class_name: "GithubIssuePublish::ReconciliationRetryJob",
                    active_job_id: "active-job-queue-health",
                    failed_at: now,
                    operations: {
                      retryable: true,
                      discardable: true,
                      retry_reason_templates: ["operator_confirmed_safe_retry", "transient_failure_recovered"],
                      discard_reason_templates: ["manually_resolved", "unsafe_to_retry"],
                      reason_templates: ["operator_confirmed_safe_retry", "manually_resolved", "unsafe_to_retry"],
                    },
                  },
                ],
            failed_job_operation_metrics: {
              recent_window_hours: 24,
              retry_count: healthy ? 1 : 0,
              discard_count: 0,
              rejected_count: healthy ? 0 : 1,
              last_operated_at: healthy ? now : undefined,
            },
            failed_job_operation_history: healthy
              ? [
                  {
                    id: "7fa2360e-4b5b-48d4-a130-2f3b2a9db708",
                    action: "retry",
                    outcome: "succeeded",
                    actor_id: "admin-actor",
                    summary: "失敗ジョブの再実行が要求されました。",
                    failed_job_id: 456,
                    job_id: 123,
                    product_job_id: "18b92270-8f9f-45cb-a8d0-6f7442ce8241",
                    project_boundary_status: "verified",
                    product_job_mapping_source: "explicit",
                    reason_template: "operator_confirmed_safe_retry",
                    reason_template_label: "運用者が副作用リスクを確認したため再実行します。",
                    created_at: now,
                  },
                ]
              : [
                  {
                    id: "bb983a8e-067b-4ed0-8cfc-ef12e6f0a016",
                    action: "boundary_rejected",
                    outcome: "rejected",
                    actor_id: "admin-actor",
                    summary: "失敗ジョブ操作のProject境界検証に失敗しました。",
                    failed_job_id: "455",
                    project_boundary_status: "project_mismatch",
                    created_at: now,
                  },
                ],
            recurring_tasks: [{ key: "cleanup_expired_github_connection_states", class_name: "GithubConnectionStateCleanupJob", queue_name: "default", schedule: "*/10 * * * *" }],
            product_jobs: {
              by_status: [
                { status: "queued", count: 0 },
                { status: "running", count: 0 },
                { status: "succeeded", count: 7 },
                { status: "failed", count: healthy ? 0 : 1 },
                { status: "cancelled", count: 0 },
              ],
              recent_failed_count: healthy ? 0 : 1,
            },
            warnings: healthy ? [] : ["failed executionが1件あります。"],
          },
        }),
      });
    });

    await page.route("**/api/v1/operations/failed-jobs/456/retry**", async (route) => {
      operationRequests += 1;
      const body = route.request().postDataJSON();
      expect(body.reason_template).toBe("operator_confirmed_safe_retry");
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            failed_job_id: 456,
            job_id: 123,
            product_job_id: "18b92270-8f9f-45cb-a8d0-6f7442ce8241",
            project_id: projectId,
            project_boundary_status: "verified",
            product_job_mapping_source: "explicit",
            action: "retry",
            queue_name: "github_reconciliation",
            class_name: "GithubIssuePublish::ReconciliationRetryJob",
            reason_template: "operator_confirmed_safe_retry",
            operated_at: now,
          },
        }),
      });
    });

    await page.goto("/");

    const panel = page.getByLabel("運用監視");
    await expect(panel.getByText("要確認")).toBeVisible();
    await expect(panel.getByText("全1件 / 古い応答1件")).toBeVisible();
    await expect(panel.getByText("2件 / 420秒")).toBeVisible();
    const failedJobs = panel.getByLabel("直近失敗ジョブ");
    await expect(failedJobs).toContainText("GithubIssuePublish::ReconciliationRetryJob");
    await expect(failedJobs).toContainText("github_reconciliation");
    await expect(failedJobs).toContainText("管理ジョブID: 18b92270-8f9f-45cb-a8d0-6f7442ce8241");
    await expect(failedJobs).toContainText("Project境界確認済み");
    await expect(failedJobs).toContainText("境界根拠: 明示マッピング");
    await expect(failedJobs.getByLabel("再実行理由")).toBeVisible();
    await expect(failedJobs.getByLabel("破棄理由")).toBeVisible();
    await failedJobs.getByRole("button", { name: "破棄" }).click();
    await expect(page.getByText("破棄前にリスク確認が必要です。")).toBeVisible();
    expect(operationRequests).toBe(0);
    await failedJobs.getByRole("button", { name: "再実行" }).click();
    await expect(page.getByText("失敗ジョブを再実行しました")).toBeVisible();
    expect(operationRequests).toBe(1);
    await expect(panel.getByText("正常")).toBeVisible();
    await expect(panel.getByText("再実行1件 / 破棄0件 / 拒否0件")).toBeVisible();
    await expect(panel.getByLabel("失敗ジョブ操作履歴")).toContainText("失敗ジョブの再実行が要求されました。");
    await expect(panel.getByLabel("失敗ジョブ操作履歴")).toContainText("境界根拠: 明示マッピング");

    queueHealthRequests = 0;
    await panel.getByRole("button", { name: "運用状態更新" }).click();
    await expect(panel.getByText("要確認")).toBeVisible();
    await expect(panel.getByText("failed executionが1件あります。")).toBeVisible();
    await expect(panel).not.toContainText("DATABASE_URL");
    await expect(panel).not.toContainText("backtrace");
    await expect(panel).not.toContainText("secret-token");

    await panel.getByRole("button", { name: "運用状態更新" }).click();

    await expect(panel.getByText("正常")).toBeVisible();
    await expect(panel.getByText("全1件 / 古い応答0件")).toBeVisible();
    await expect(panel.getByText("0件 / -")).toBeVisible();
    await expect(panel.getByLabel("直近失敗ジョブ")).toHaveCount(0);
    await expect(panel.getByText("failed executionが1件あります。")).toHaveCount(0);
  });
});
