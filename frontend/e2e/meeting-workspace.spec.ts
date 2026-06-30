import { expect, test, type APIRequestContext, type Page } from "@playwright/test";

const apiBaseUrl = process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://127.0.0.1:3001/api/v1";

test.describe("Meeting Workspace", () => {
  type GenerationFailure = {
    name: string;
    code: string;
    message: string;
    status: number;
    jobId: string;
    requestId?: string;
  };

  const providerFailures: GenerationFailure[] = [
    {
      name: "OpenAI upstream failure",
      code: "openai_api_error",
      message: "OpenAI request failed. Retry later or check integration settings.",
      status: 502,
      jobId: "job_openai_upstream",
      requestId: "req_openai_upstream",
    },
    {
      name: "invalid AI response",
      code: "invalid_ai_response",
      message: "AI response did not match the expected minutes schema.",
      status: 502,
      jobId: "job_invalid_ai_response",
      requestId: "req_invalid_ai_response",
    },
    {
      name: "OpenAI rate limit",
      code: "rate_limit_exceeded",
      message: "OpenAI request was rate limited. Retry after the provider limit resets.",
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
    await page.getByLabel("Name").fill(projectName);
    await page.getByLabel("GitHub repo").fill("Kazuya-Sakashita/ai-pm-platform");
    await page.getByRole("button", { name: "Create Project" }).click();
    await expect(page.getByRole("heading", { name: projectName })).toBeVisible();
  }

  async function saveMeeting(page: Page, meetingTitle: string, rawText: string) {
    await page.getByLabel("Title").fill(meetingTitle);
    await page.getByLabel("Raw text").fill(rawText);
    await page.getByRole("button", { name: "Save Meeting" }).click();
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

  test("shows validation errors when required meeting fields are missing", async ({ page, request }) => {
    await expectApiHealth(request);
    const stamp = Date.now();

    await createProject(page, `E2E Validation Project ${stamp}`);
    await page.getByLabel("Title").fill("");
    await page.getByLabel("Raw text").fill("");
    await page.getByRole("button", { name: "Save Meeting" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("Validation failed");
    await expect(page.locator("header").getByText("API error")).toBeVisible();
  });

  test("blocks secret-like content and surfaces the failed generation job", async ({ page, request }) => {
    await expectApiHealth(request);
    const stamp = Date.now();
    const meetingTitle = `E2E Secret Block ${stamp}`;

    await createProject(page, `E2E Secret Project ${stamp}`);
    await saveMeeting(page, meetingTitle, "alice: password=super-secret-value");

    await page.getByRole("button", { name: "Generate" }).click();

    await expect(page.locator("section[role='alert']")).toContainText("Meeting text includes sensitive content");
    await expect(page.locator("header").getByText("job failed")).toBeVisible();
    await expect(page.locator("#review").getByText("Minutes generated")).toBeVisible();
    await expect(page.locator("#review").getByText("no")).toHaveCount(2);
  });

  for (const failure of providerFailures) {
    test(`surfaces ${failure.name} as a failed generation job`, async ({ page, request }) => {
      await expectApiHealth(request);
      const stamp = Date.now();
      const meetingTitle = `E2E ${failure.name} ${stamp}`;

      await createProject(page, `E2E Provider Failure Project ${stamp}`);
      await saveMeeting(page, meetingTitle, "alice: Decision: keep AI failures visible and recoverable.");
      await mockGenerationFailure(page, failure);

      await page.getByRole("button", { name: "Generate" }).click();

      await expect(page.locator("section[role='alert']")).toContainText(failure.message);
      await expect(page.locator("header").getByText("API error")).toBeVisible();
      await expect(page.locator("header").getByText("job failed")).toBeVisible();
      await expect(page.getByText("failed / minutes")).toBeVisible();
      await expect(page.locator("#review").getByText("Minutes generated")).toBeVisible();
      await expect(page.locator("#review").getByText("no")).toHaveCount(2);
    });
  }
});
