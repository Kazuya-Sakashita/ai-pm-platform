import { expect, test } from "@playwright/test";

const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1";

test.describe("Meeting Workspace", () => {
  test("creates a project, saves a Discord log, generates minutes, and requests review", async ({ page, request }) => {
    const health = await request.get(`${apiBaseUrl}/health`);
    expect(health.ok(), `Rails API must be running at ${apiBaseUrl}`).toBe(true);

    const stamp = Date.now();
    const projectName = `E2E Project ${stamp}`;
    const meetingTitle = `E2E Discord Sync ${stamp}`;
    const rawText = [
      "alice: Decision: connect Playwright smoke coverage.",
      "bob: Open question: who reviews the generated minutes?",
      "alice: Action: request review after minutes are generated.",
    ].join("\n");

    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Discordログから議事録を生成" })).toBeVisible();

    await page.getByLabel("Name").fill(projectName);
    await page.getByLabel("GitHub repo").fill("Kazuya-Sakashita/ai-pm-platform");
    await page.getByRole("button", { name: "Create Project" }).click();
    await expect(page.getByRole("heading", { name: projectName })).toBeVisible();

    await page.getByLabel("Title").fill(meetingTitle);
    await page.getByLabel("Raw text").fill(rawText);
    await page.getByRole("button", { name: "Save Meeting" }).click();
    await expect(page.getByRole("button", { name: new RegExp(meetingTitle) })).toBeVisible();

    await page.getByRole("button", { name: "Generate" }).click();
    await expect(page.getByText("Minutes generated")).toBeVisible();
    await expect(page.getByLabel("Summary")).toHaveValue(/Playwright smoke coverage/);
    await expect(page.getByLabel("Decisions")).toHaveValue(/connect Playwright smoke coverage/);
    await expect(page.getByLabel("Open questions")).toHaveValue(/who reviews/);
    await expect(page.getByLabel("Action items")).toHaveValue(/request review/);

    await page.getByRole("button", { name: "Request Review" }).click();
    await expect(page.locator("header").getByText("Review requested")).toBeVisible();
    await expect(page.getByText("open / Product Manager")).toBeVisible();

    await page.getByRole("button", { name: "Approve Minutes" }).click();
    await expect(page.getByText("Minutes approved")).toBeVisible();
    await expect(page.locator("#review").getByText("clear")).toBeVisible();
  });
});
