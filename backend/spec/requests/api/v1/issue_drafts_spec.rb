require "rails_helper"
require "digest"

RSpec.describe "API V1 Issue Drafts", type: :request do
  describe "POST /api/v1/requirements/:id/generate-issue-draft" do
    it "generates an issue draft from an approved requirement" do
      requirement = create(
        :requirement,
        status: "approved",
        open_questions: [],
        goal: "Generate GitHub Issue drafts from approved requirements.",
        functional_requirements: ["FR-001: Generate issue drafts."],
        acceptance_criteria: ["Given an approved requirement, when generation runs, then an issue draft is stored."]
      )

      post "/api/v1/requirements/#{requirement.id}/generate-issue-draft"

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("data", "job_id"))
      issue_draft = IssueDraft.find(job.target_id)
      expect(job.status).to eq("succeeded")
      expect(job.target_type).to eq("issue_draft")
      expect(issue_draft.title).to include("Generate GitHub Issue drafts")
      expect(issue_draft.body).to include("## Acceptance Criteria")
      expect(issue_draft.labels).to include("ai-generated", "requirement")
      expect(requirement.minute.meeting.project.audit_logs.last.action).to eq("issue_draft.generated")
    end

    it "requires an approved requirement before generation" do
      requirement = create(:requirement, status: "generated")

      post "/api/v1/requirements/#{requirement.id}/generate-issue-draft"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "status")).to eq("generated")
      expect(Job.where(target_type: "issue_draft")).to be_empty
    end
  end

  describe "GET /api/v1/issue-drafts/:id" do
    it "returns an issue draft" do
      issue_draft = create(:issue_draft)

      get "/api/v1/issue-drafts/#{issue_draft.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(issue_draft.id)
    end
  end

  describe "PATCH /api/v1/issue-drafts/:id" do
    it "updates an editable issue draft" do
      issue_draft = create(:issue_draft)

      patch "/api/v1/issue-drafts/#{issue_draft.id}", params: {
        title: "Updated issue title",
        body: "Updated issue body",
        acceptance_criteria: ["Updated criterion"],
        labels: ["updated", "needs-review"]
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "title")).to eq("Updated issue title")
      expect(body.dig("data", "labels")).to eq(["updated", "needs-review"])
      expect(issue_draft.requirement.minute.meeting.project.audit_logs.last.action).to eq("issue_draft.updated")
    end
  end

  describe "POST /api/v1/issue-drafts/:id/publish-github" do
    it "publishes an approved issue draft when gates are clear" do
      issue_draft = create(:issue_draft, status: "approved")
      open_api_draft = create(:open_api_draft, requirement: issue_draft.requirement, status: "valid")
      provider = instance_double(
        GithubIssuePublish::DryRunProvider,
        publish: {
          github_issue_number: 42,
          github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
          github_repository: "Kazuya-Sakashita/ai-pm-platform",
          github_issue_api_id: 420,
          github_issue_node_id: "I_kwDUMMY"
        }
      )
      allow(GithubIssuePublish::ProviderFactory).to receive(:build).and_return(provider)

      post "/api/v1/issue-drafts/#{issue_draft.id}/publish-github", headers: { "Idempotency-Key" => "publish-key-1" }

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("published")
      expect(body.dig("data", "github_issue_number")).to eq(42)
      issue_draft.reload
      expect(issue_draft.status).to eq("published")
      expect(issue_draft.github_issue_url).to eq("https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42")
      expect(issue_draft.publish_idempotency_key).to eq(Digest::SHA256.hexdigest("publish-key-1"))
      attempt = issue_draft.github_issue_publish_attempts.last
      expect(attempt.status).to eq("local_saved")
      expect(attempt.github_issue_number).to eq(42)
      job = Job.where(job_type: "github_publish", target_type: "issue_draft", target_id: issue_draft.id).last
      expect(job.status).to eq("succeeded")
      audit_log = issue_draft.requirement.minute.meeting.project.audit_logs.find_by!(action: "issue_draft.github_published")
      expect(audit_log.metadata).to include("job_id" => job.id, "github_issue_number" => 42, "openapi_draft_id" => open_api_draft.id)
    end

    it "blocks unapproved issue drafts" do
      issue_draft = create(:issue_draft, status: "draft")
      create(:open_api_draft, requirement: issue_draft.requirement, status: "valid")

      post "/api/v1/issue-drafts/#{issue_draft.id}/publish-github"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("issue_draft_review_required")
      expect(Job.where(job_type: "github_publish")).to be_empty
    end

    it "blocks when OpenAPI validation has not passed" do
      issue_draft = create(:issue_draft, status: "approved")
      open_api_draft = create(:open_api_draft, requirement: issue_draft.requirement, status: "invalid")

      post "/api/v1/issue-drafts/#{issue_draft.id}/publish-github"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("openapi_validation_required")
      expect(body.dig("error", "details", "openapi_draft_id")).to eq(open_api_draft.id)
    end

    it "blocks when an OpenAPI review blocker is unresolved" do
      issue_draft = create(:issue_draft, status: "approved")
      open_api_draft = create(:open_api_draft, requirement: issue_draft.requirement, status: "valid")
      review = create(
        :review,
        target_type: "openapi_draft",
        target_id: open_api_draft.id,
        reviewer_role: "OpenAPI Validator",
        status: "action_required"
      )

      post "/api/v1/issue-drafts/#{issue_draft.id}/publish-github"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("openapi_review_blocker")
      expect(body.dig("error", "details", "review_id")).to eq(review.id)
    end

    it "returns integration_not_connected when GitHub provider is disabled" do
      issue_draft = create(:issue_draft, status: "approved")
      create(:open_api_draft, requirement: issue_draft.requirement, status: "valid")

      post "/api/v1/issue-drafts/#{issue_draft.id}/publish-github"

      expect(response).to have_http_status(:failed_dependency)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_integration_not_connected")
      expect(issue_draft.reload.status).to eq("publish_failed")
      attempt = issue_draft.github_issue_publish_attempts.last
      expect(attempt.status).to eq("failed")
      expect(attempt.safe_error_code).to eq("github_integration_not_connected")
      job = Job.where(job_type: "github_publish", target_type: "issue_draft", target_id: issue_draft.id).last
      expect(job.status).to eq("failed")
      expect(job.safe_error_detail).to eq("GitHub integration is not connected.")
    end
  end

  describe "POST /api/v1/issue-drafts/:id/reconcile-github-publish" do
    it "reconciles the latest pending publish attempt" do
      issue_draft = create(:issue_draft, status: "publish_failed", publish_error: "Reconciliation required.")
      project = issue_draft.requirement.minute.meeting.project
      attempt = create(
        :github_issue_publish_attempt,
        issue_draft: issue_draft,
        project: project,
        status: "reconciliation_required",
        idempotency_digest: Digest::SHA256.hexdigest("publish-key-1")
      )
      search_client = instance_double(
        GithubIssuePublish::MarkerSearchClient,
        search: [
          {
            github_issue_number: 42,
            github_issue_url: "https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42",
            github_repository: "Kazuya-Sakashita/ai-pm-platform",
            github_issue_api_id: 420,
            github_issue_node_id: "I_kwRECONCILE"
          }
        ]
      )
      allow(GithubIssuePublish::MarkerSearchClient).to receive(:new).and_return(search_client)

      post "/api/v1/issue-drafts/#{issue_draft.id}/reconcile-github-publish"

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("reconciled")
      expect(body.dig("data", "attempt_id")).to eq(attempt.id)
      expect(body.dig("data", "match_count")).to eq(1)
      expect(body.dig("data", "github_issue_number")).to eq(42)
      expect(issue_draft.reload.status).to eq("published")
      expect(attempt.reload.status).to eq("reconciled")
      job = Job.find(body.dig("data", "job_id"))
      expect(job.job_type).to eq("github_reconciliation")
      expect(job.status).to eq("succeeded")
    end

    it "returns a review blocker when reconciliation is ambiguous" do
      issue_draft = create(:issue_draft, status: "publish_failed", publish_error: "Reconciliation required.")
      project = issue_draft.requirement.minute.meeting.project
      attempt = create(
        :github_issue_publish_attempt,
        issue_draft: issue_draft,
        project: project,
        status: "reconciliation_required",
        idempotency_digest: Digest::SHA256.hexdigest("publish-key-2")
      )
      allow(GithubIssuePublish::MarkerSearchClient).to receive(:new).and_return(
        instance_double(GithubIssuePublish::MarkerSearchClient, search: [])
      )

      post "/api/v1/issue-drafts/#{issue_draft.id}/reconcile-github-publish"

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("review_required")
      expect(body.dig("data", "attempt_id")).to eq(attempt.id)
      expect(body.dig("data", "match_count")).to eq(0)
      expect(body.dig("data", "review_id")).to be_present
      expect(attempt.reload.status).to eq("reconciliation_required")
      review = Review.find(body.dig("data", "review_id"))
      expect(review.status).to eq("action_required")
    end

    it "blocks when no reconciliation attempt is pending" do
      issue_draft = create(:issue_draft, status: "approved")

      post "/api/v1/issue-drafts/#{issue_draft.id}/reconcile-github-publish"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_publish_reconciliation_not_required")
      expect(Job.where(job_type: "github_reconciliation")).to be_empty
    end

    it "marks the job failed when GitHub marker search fails" do
      issue_draft = create(:issue_draft, status: "publish_failed", publish_error: "Reconciliation required.")
      project = issue_draft.requirement.minute.meeting.project
      attempt = create(
        :github_issue_publish_attempt,
        issue_draft: issue_draft,
        project: project,
        status: "reconciliation_required",
        idempotency_digest: Digest::SHA256.hexdigest("publish-key-3")
      )
      search_client = instance_double(GithubIssuePublish::MarkerSearchClient)
      allow(search_client).to receive(:search).and_raise(
        GithubIssuePublish::ProviderError.new(
          code: "github_issue_marker_search_failed",
          message: "GitHub search failed.",
          safe_detail: "GitHub Issue marker search failed.",
          http_status: :bad_gateway
        )
      )
      allow(GithubIssuePublish::MarkerSearchClient).to receive(:new).and_return(search_client)

      post "/api/v1/issue-drafts/#{issue_draft.id}/reconcile-github-publish"

      expect(response).to have_http_status(:bad_gateway)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_issue_marker_search_failed")
      expect(body.dig("error", "details", "attempt_id")).to eq(attempt.id)
      job = Job.where(job_type: "github_reconciliation", target_id: issue_draft.id).last
      expect(job.status).to eq("failed")
      expect(job.safe_error_detail).to eq("GitHub Issue marker search failed.")
      audit_log = project.audit_logs.find_by!(action: "issue_draft.github_publish_reconciliation_failed")
      expect(audit_log.metadata).to include("job_id" => job.id, "attempt_id" => attempt.id)
    end
  end
end
