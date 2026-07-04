import { expect, test } from "@playwright/test";

test.describe("GitHub callback result", () => {
  test("completes a GitHub callback without exposing the raw state", async ({ page }) => {
    const now = new Date().toISOString();
    let callbackPayload: unknown;

    await page.route("**/api/v1/integrations/github/callback", async (route) => {
      callbackPayload = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: {
            id: "integration-github-callback",
            project_id: "project-github-callback",
            provider: "github",
            status: "connected",
            repository_owner: "Kazuya-Sakashita",
            repository_name: "ai-pm-platform",
            github_installation_id: "987654",
            github_account_login: "Kazuya-Sakashita",
            github_account_type: "User",
            granted_permissions: { metadata: "read", issues: "write" },
            last_sync_at: now,
            created_at: now,
            updated_at: now,
          },
        }),
      });
    });

    await page.goto("/github/callback?state=signed-state-secret&installation_id=987654&setup_action=install");

    await expect(page.getByRole("heading", { name: "接続が完了しました" })).toBeVisible();
    await expect(page.getByText("GitHub連携が完了しました。")).toBeVisible();
    await expect(page.getByLabel("GitHub接続結果").getByText("Kazuya-Sakashita/ai-pm-platform")).toBeVisible();
    await expect(page.getByLabel("GitHub接続結果").getByText("Kazuya-Sakashita", { exact: true })).toBeVisible();
    await expect(page.getByRole("link", { name: "ワークスペースへ戻る" })).toBeVisible();
    await expect(page.getByText("signed-state-secret")).toHaveCount(0);
    expect(callbackPayload).toMatchObject({
      installation_id: "987654",
      state: "signed-state-secret",
      setup_action: "install",
    });
  });

  test("shows a safe retry message when backend rejects the callback state", async ({ page }) => {
    await page.route("**/api/v1/integrations/github/callback", async (route) => {
      await route.fulfill({
        status: 401,
        contentType: "application/json",
        body: JSON.stringify({
          error: {
            code: "github_state_invalid",
            message: "GitHub connection state already used.",
          },
          request_id: "playwright-request",
        }),
      });
    });

    await page.goto("/github/callback?state=used-state-secret&installation_id=987654&setup_action=update");

    await expect(page.getByRole("heading", { name: "接続を完了できませんでした" })).toBeVisible();
    await expect(page.getByText("GitHub接続リンクは使用済みです。ワークスペースから接続をやり直してください。")).toBeVisible();
    await expect(page.getByLabel("GitHub接続結果").getByText("更新")).toBeVisible();
    await expect(page.getByRole("link", { name: "GitHub接続をやり直す" })).toBeVisible();
    await expect(page.getByText("used-state-secret")).toHaveCount(0);
  });

  test("blocks callback completion when required query parameters are missing", async ({ page }) => {
    let callbackRequested = false;
    await page.setViewportSize({ width: 390, height: 760 });

    await page.route("**/api/v1/integrations/github/callback", async (route) => {
      callbackRequested = true;
      await route.fulfill({ status: 500, contentType: "application/json", body: "{}" });
    });

    await page.goto("/github/callback?installation_id=987654");

    await expect(page.getByRole("heading", { name: "接続を完了できませんでした" })).toBeVisible();
    await expect(page.getByText("GitHubから必要な接続情報を受け取れませんでした。")).toBeVisible();
    expect(callbackRequested).toBe(false);
    await expect
      .poll(async () => page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth))
      .toBe(true);
  });
});
