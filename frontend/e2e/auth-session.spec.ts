import { expect, test, type Page } from "@playwright/test";

const now = new Date("2026-07-06T08:00:00.000Z").toISOString();

const project = {
  id: "project-auth-session",
  name: "Auth Session Project",
  github_repo: "Kazuya-Sakashita/ai-pm-platform",
  description: "Mocked project for auth session E2E.",
  status: "active",
  created_at: now,
  updated_at: now,
};

const currentSession = {
  id: "11111111-1111-4111-8111-111111111111",
  status: "active",
  current: true,
  issued_at: now,
  expires_at: "2026-07-06T08:15:00.000Z",
  last_seen_at: now,
  revoked_at: null,
  revocation_reason: null,
  created_at: now,
  updated_at: now,
};

const otherSession = {
  id: "22222222-2222-4222-8222-222222222222",
  status: "active",
  current: false,
  issued_at: now,
  expires_at: "2026-07-06T09:00:00.000Z",
  last_seen_at: now,
  revoked_at: null,
  revocation_reason: null,
  created_at: now,
  updated_at: now,
};

async function enableBearerAuth(page: Page) {
  await page.addInitScript(() => {
    window.localStorage.setItem("ai-pm-auth-token", "playwright-session-token");
    window.localStorage.removeItem("ai-pm-auth-cleared");
  });
}

async function mockBaseWorkspace(page: Page, options: { projectAuthError?: string; queueAuthError?: string } = {}) {
  let sessions = [currentSession, otherSession];

  await page.route("**/api/v1/auth/sessions", async (route) => {
    if (route.request().method() !== "GET") return route.fallback();
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        data: sessions,
        meta: {
          current_session_id: currentSession.id,
          active_count: sessions.filter((session) => session.status === "active").length,
          total_count: sessions.length,
        },
      }),
    });
  });

  await page.route(`**/api/v1/auth/sessions/${otherSession.id}`, async (route) => {
    if (route.request().method() !== "DELETE") return route.fallback();
    const revoked = {
      ...otherSession,
      status: "revoked",
      revoked_at: now,
      revocation_reason: "logout",
      updated_at: now,
    };
    sessions = [currentSession, revoked];
    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: revoked }) });
  });

  await page.route("**/api/v1/auth/sessions/current", async (route) => {
    if (route.request().method() !== "DELETE") return route.fallback();
    const revoked = {
      ...currentSession,
      status: "revoked",
      revoked_at: now,
      revocation_reason: "logout",
      updated_at: now,
    };
    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: revoked }) });
  });

  await page.route("**/api/v1/auth/logout-everywhere", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        data: {
          revoked_session_count: 2,
          session_version: 2,
          sessions_revoked_at: now,
        },
      }),
    });
  });

  await page.route("**/api/v1/operations/queue-health", async (route) => {
    if (options.queueAuthError) {
      await route.fulfill({
        status: 401,
        contentType: "application/json",
        body: JSON.stringify({
          error: {
            code: options.queueAuthError,
            message: "Authentication session has been revoked.",
          },
          request_id: "playwright-request",
        }),
      });
      return;
    }

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
    if (route.request().method() !== "GET") return route.fallback();
    if (options.projectAuthError) {
      await route.fulfill({
        status: 401,
        contentType: "application/json",
        body: JSON.stringify({
          error: {
            code: options.projectAuthError,
            message: "Authentication session has been revoked.",
          },
          request_id: "playwright-request",
        }),
      });
      return;
    }

    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [project], meta: { total_count: 1 } }) });
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
  await page.route(`**/api/v1/projects/${project.id}/conversation-imports`, async (route) => {
    await route.fulfill({ status: 200, contentType: "application/json", body: JSON.stringify({ data: [], meta: { total_count: 0 } }) });
  });
}

test.describe("Auth session recovery", () => {
  test("locks and clears the workspace when the primary project load returns a revoked session", async ({ page }) => {
    await enableBearerAuth(page);
    await page.setViewportSize({ width: 390, height: 760 });
    await mockBaseWorkspace(page, { projectAuthError: "session_revoked" });

    await page.goto("/");

    await expect(page.getByRole("heading", { name: "再ログインが必要です" })).toBeVisible();
    await expect(page.getByText("ログインセッションは失効しています。再ログインしてください。")).toBeVisible();
    await expect(page.getByRole("button", { name: "プロジェクト作成" })).toHaveCount(0);
    await expect(page.getByText("Discord-first")).toHaveCount(0);
    await expect.poll(async () => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  });

  test("locks the workspace when a background request returns a stale session", async ({ page }) => {
    await enableBearerAuth(page);
    await mockBaseWorkspace(page, { queueAuthError: "session_version_stale" });

    await page.goto("/");

    await expect(page.getByRole("heading", { name: "再ログインが必要です" })).toBeVisible();
    await expect(page.getByText("他の端末または管理者操作によりログイン状態が更新されました。")).toBeVisible();
    await expect(page.getByRole("heading", { name: project.name })).toHaveCount(0);
  });

  test("shows session list, revokes another session, and locks after current logout", async ({ page }) => {
    await enableBearerAuth(page);
    await mockBaseWorkspace(page);
    page.on("dialog", (dialog) => dialog.accept());

    await page.goto("/");

    await expect(page.getByRole("heading", { name: project.name })).toBeVisible();
    await expect(page.getByLabel("ログインセッション一覧").getByText("この端末")).toBeVisible();
    await expect(page.getByLabel("ログインセッション一覧").getByText("他の端末")).toBeVisible();

    await page.getByRole("button", { name: "このセッションを失効" }).click();
    await expect(page.getByLabel("ログインセッション一覧").getByText("失効済み")).toBeVisible();

    await page.getByRole("button", { name: "この端末からログアウト" }).click();
    await expect(page.getByRole("heading", { name: "再ログインが必要です" })).toBeVisible();
    await expect(page.getByRole("button", { name: "プロジェクト作成" })).toHaveCount(0);
  });
});
