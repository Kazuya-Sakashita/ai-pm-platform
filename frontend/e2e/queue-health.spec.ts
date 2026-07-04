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

    await page.route("**/api/v1/operations/queue-health", async (route) => {
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

    await page.goto("/");

    const panel = page.getByLabel("運用監視");
    await expect(panel.getByText("要確認")).toBeVisible();
    await expect(panel.getByText("全1件 / 古い応答1件")).toBeVisible();
    await expect(panel.getByText("2件 / 420秒")).toBeVisible();
    await expect(panel.getByText("failed executionが1件あります。")).toBeVisible();
    await expect(panel).not.toContainText("DATABASE_URL");
    await expect(panel).not.toContainText("backtrace");

    await panel.getByRole("button", { name: "運用状態更新" }).click();

    await expect(panel.getByText("正常")).toBeVisible();
    await expect(panel.getByText("全1件 / 古い応答0件")).toBeVisible();
    await expect(panel.getByText("0件 / -")).toBeVisible();
    await expect(panel.getByText("failed executionが1件あります。")).toHaveCount(0);
  });
});
