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
    let discardApprovalStatus: "none" | "pending" | "approved" = "none";
    const discardApprovalId = "70a7e7e0-6f16-4bd5-a357-35ad08f5ff97";
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
      const healthy = operationRequests > 0;
      const discardApproval =
        discardApprovalStatus === "none"
          ? null
          : {
              id: discardApprovalId,
              project_id: projectId,
              failed_job_id: 456,
              job_id: 123,
              product_job_id: "18b92270-8f9f-45cb-a8d0-6f7442ce8241",
              queue_name: "github_reconciliation",
              class_name: "GithubIssuePublish::ReconciliationRetryJob",
              reason_template: "manually_resolved",
              discard_safety_confirmed: true,
              status: discardApprovalStatus,
              requested_by_actor_id: "admin-actor",
              approved_by_actor_id: discardApprovalStatus === "approved" ? "release-owner" : undefined,
              approval_note_present: discardApprovalStatus === "approved",
              expires_at: now,
              created_at: now,
              updated_at: now,
            };

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
                      discard_approval: discardApproval,
                      reason_templates: ["operator_confirmed_safe_retry", "manually_resolved", "unsafe_to_retry"],
                    },
                  },
                ],
            failed_job_operation_metrics: {
              recent_window_hours: 24,
              retry_count: healthy ? 1 : 0,
              discard_count: 0,
              rejected_count: healthy ? 0 : 1,
              retry_refailure: {
                measured: true,
                window_hours: 24,
                retry_count: healthy ? 1 : 4,
                rate: healthy ? 0 : 0.25,
                numerator: healthy ? 0 : 1,
                denominator: healthy ? 0 : 4,
                threshold: 0.1,
                exclusions: {
                  missing_product_job_id: 0,
                  missing_solid_queue_job_id: 0,
                  mapping_mismatch: 0,
                  solid_queue_unavailable: 0,
                },
              },
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
            failed_job_release_gate: healthy
              ? {
                  status: "pass",
                  notification_required: true,
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
                  checks: [
                    {
                      key: "boundary_rejected_count",
                      label: "Project境界拒否件数",
                      status: "pass",
                      severity: "critical",
                      observed_value: "0件",
                      threshold: "0件",
                      next_action: "権限境界またはmapping異常としてreleaseを止め、Security Engineerが確認します。",
                    },
                    {
                      key: "retry_refailure_rate",
                      label: "retry後再失敗率",
                      status: "pass",
                      severity: "info",
                      observed_value: "0.0% (0/0)",
                      threshold: "10%未満",
                      next_action: "retry後再失敗率は閾値内です。継続監視します。",
                    },
                  ],
                }
              : {
                  status: "blocked",
                  notification_required: true,
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
                  checks: [
                    {
                      key: "worker_heartbeat",
                      label: "worker heartbeat",
                      status: "warning",
                      severity: "warning",
                      observed_value: "古い応答1件",
                      threshold: "60秒以内",
                      next_action: "worker processとqueue database接続を確認します。",
                    },
                    {
                      key: "boundary_rejected_count",
                      label: "Project境界拒否件数",
                      status: "blocked",
                      severity: "critical",
                      observed_value: "1件",
                      threshold: "0件",
                      next_action: "権限境界またはmapping異常としてreleaseを止め、Security Engineerが確認します。",
                    },
                    {
                      key: "retry_refailure_rate",
                      label: "retry後再失敗率",
                      status: "warning",
                      severity: "warning",
                      observed_value: "25.0% (1/4)",
                      threshold: "10%未満",
                      next_action: "retry理由、再失敗job、外部API状態を確認し、必要ならretryを停止します。",
                    },
                  ],
                },
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

    await page.route("**/api/v1/operations/failed-jobs/456/discard-approval-requests**", async (route) => {
      const body = route.request().postDataJSON();
      expect(body.reason_template).toBe("manually_resolved");
      expect(body.discard_safety_confirmed).toBe(true);
      discardApprovalStatus = "pending";
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            id: discardApprovalId,
            project_id: projectId,
            failed_job_id: 456,
            job_id: 123,
            product_job_id: "18b92270-8f9f-45cb-a8d0-6f7442ce8241",
            queue_name: "github_reconciliation",
            class_name: "GithubIssuePublish::ReconciliationRetryJob",
            reason_template: "manually_resolved",
            discard_safety_confirmed: true,
            status: "pending",
            requested_by_actor_id: "admin-actor",
            expires_at: now,
            created_at: now,
            updated_at: now,
          },
        }),
      });
    });

    await page.route(`**/api/v1/operations/failed-job-discard-approvals/${discardApprovalId}/approve**`, async (route) => {
      const body = route.request().postDataJSON();
      expect(body.approval_note).toContain("復旧不要");
      discardApprovalStatus = "approved";
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            id: discardApprovalId,
            project_id: projectId,
            failed_job_id: 456,
            job_id: 123,
            queue_name: "github_reconciliation",
            class_name: "GithubIssuePublish::ReconciliationRetryJob",
            reason_template: "manually_resolved",
            discard_safety_confirmed: true,
            status: "approved",
            requested_by_actor_id: "admin-actor",
            approved_by_actor_id: "release-owner",
            approval_note_present: true,
            expires_at: now,
            approved_at: now,
            created_at: now,
            updated_at: now,
          },
        }),
      });
    });

    await page.route(/\/api\/v1\/operations\/failed-jobs\/456\/discard\?/, async (route) => {
      operationRequests += 1;
      const body = route.request().postDataJSON();
      expect(body.reason_template).toBe("manually_resolved");
      expect(body.discard_safety_confirmed).toBe(true);
      expect(body.discard_approval_id).toBe(discardApprovalId);
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
            action: "discard",
            queue_name: "github_reconciliation",
            class_name: "GithubIssuePublish::ReconciliationRetryJob",
            reason_template: "manually_resolved",
            discard_safety_confirmed: true,
            discard_approval_id: discardApprovalId,
            discard_approval_requested_by_actor_id: "admin-actor",
            discard_approval_approved_by_actor_id: "release-owner",
            discard_approval_expires_at: now,
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
    await expect(panel.getByText("リリースゲート").first()).toBeVisible();
    await expect(panel.getByText("停止").first()).toBeVisible();
    await expect(panel.getByText("通知")).toBeVisible();
    await expect(panel.getByText("必要 / operations")).toBeVisible();
    await expect(panel.getByLabel("失敗ジョブリリースゲート")).toContainText("Project境界拒否件数");
    await expect(panel.getByLabel("失敗ジョブリリースゲート")).toContainText("二人承認 / ownerまたはrelease owner");
    const failedJobs = panel.getByLabel("直近失敗ジョブ");
    await expect(failedJobs).toContainText("GithubIssuePublish::ReconciliationRetryJob");
    await expect(failedJobs).toContainText("github_reconciliation");
    await expect(failedJobs).toContainText("管理ジョブID: 18b92270-8f9f-45cb-a8d0-6f7442ce8241");
    await expect(failedJobs).toContainText("Project境界確認済み");
    await expect(failedJobs).toContainText("境界根拠: 明示マッピング");
    await expect(failedJobs.getByLabel("再実行理由")).toBeVisible();
    await expect(failedJobs.getByLabel("破棄理由")).toBeVisible();
    await expect(failedJobs).toContainText("二人承認");
    await expect(failedJobs).toContainText("未依頼");
    await expect(failedJobs.getByRole("button", { name: "破棄", exact: true })).toBeDisabled();
    await failedJobs.getByRole("button", { name: "破棄承認を依頼" }).click();
    await expect(page.getByText("破棄承認を依頼する前にリスク確認が必要です。")).toBeVisible();
    expect(operationRequests).toBe(0);
    await failedJobs.getByLabel("破棄リスクを確認").check();
    await failedJobs.getByRole("button", { name: "破棄承認を依頼" }).click();
    await expect(page.getByText("破棄承認を依頼しました")).toBeVisible();
    await expect(failedJobs).toContainText("承認待ち");
    await failedJobs.getByLabel("承認コメント").fill("復旧不要の根拠を確認しました。");
    await failedJobs.getByRole("button", { name: "承認" }).click();
    await expect(page.getByText("破棄承認を承認しました")).toBeVisible();
    await expect(failedJobs).toContainText("承認済み");
    await failedJobs.getByRole("button", { name: "破棄", exact: true }).click();
    await expect(page.getByText("失敗ジョブを破棄しました")).toBeVisible();
    expect(operationRequests).toBe(1);
    await expect(panel.getByText("正常")).toBeVisible();
    await expect(panel.getByLabel("失敗ジョブリリースゲート")).toContainText("通過");
    await expect(panel.getByText("再実行1件 / 破棄0件 / 拒否0件")).toBeVisible();

    await panel.getByRole("button", { name: "運用状態更新" }).click();
    await expect(panel).not.toContainText("DATABASE_URL");
    await expect(panel).not.toContainText("backtrace");
    await expect(panel).not.toContainText("secret-token");

    await expect(panel.getByText("正常")).toBeVisible();
    await expect(panel.getByText("全1件 / 古い応答0件")).toBeVisible();
    await expect(panel.getByText("0件 / -")).toBeVisible();
    await expect(panel.getByLabel("直近失敗ジョブ")).toHaveCount(0);
    await expect(panel.getByText("failed executionが1件あります。")).toHaveCount(0);
  });
});
