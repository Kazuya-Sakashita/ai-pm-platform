require "rails_helper"

RSpec.describe "API V1 Operations", type: :request do
  describe "GET /api/v1/operations/queue-health" do
    it "returns unavailable queue health without exposing internals when Solid Queue tables are not ready" do
      project = create(:project)
      authorize_project(project, actor_id: "admin-actor", role: "admin")
      create(:job, project: project, status: "failed", safe_error_detail: "OpenAI request failed. Retry later or check integration settings.")

      get "/api/v1/operations/queue-health", params: { project_id: project.id }, headers: auth_headers("admin-actor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      data = body.fetch("data")

      expect(data.fetch("status")).to eq("unavailable")
      expect(data.fetch("warnings").join(" ")).to include("Solid Queue")
      expect(data.fetch("failed_executions")).to eq("count" => 0)
      expect(data.fetch("failed_job_samples")).to eq([])
      expect(data.dig("product_jobs", "recent_failed_count")).to eq(1)
      expect(response.body).not_to include("OpenAI request failed")
      expect(response.body).not_to include("backtrace")
      expect(response.body).not_to include("DATABASE_URL")
      expect(response.body).not_to include("state_digest")
    end

    it "requires project admin authorization" do
      project = create(:project)
      authorize_project(project, actor_id: "viewer-actor", role: "viewer")

      get "/api/v1/operations/queue-health", params: { project_id: project.id }, headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end

    it "requires project_id after authentication" do
      get "/api/v1/operations/queue-health", headers: auth_headers("admin-actor")

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "details", "parameter")).to eq("project_id")
    end
  end

  describe "POST /api/v1/operations/failed-jobs/:failed_job_id/retry" do
    it "allows project admins to retry a failed job" do
      project = create(:project)
      authorize_project(project, actor_id: "admin-actor", role: "admin")
      stub_failed_job_operation(
        action: "retry",
        result: Operations::FailedJobOperationService::Result.new(
          success?: true,
          data: {
            failed_job_id: 456,
            job_id: 123,
            product_job_id: SecureRandom.uuid,
            project_id: project.id,
            project_boundary_status: "verified",
            action: "retry",
            queue_name: "github_reconciliation",
            class_name: "GithubIssuePublish::ReconciliationRetryJob",
            reason_template: "operator_confirmed_safe_retry",
            operated_at: "2026-07-07T12:40:00Z"
          }
        )
      )

      post "/api/v1/operations/failed-jobs/456/retry",
           params: { project_id: project.id, reason_template: "operator_confirmed_safe_retry" },
           headers: auth_headers("admin-actor"),
           as: :json

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "action")).to eq("retry")
      expect(body.to_s).not_to include("raw exception")
      expect(body.to_s).not_to include("backtrace")
    end

    it "rejects non-admin project members" do
      project = create(:project)
      authorize_project(project, actor_id: "viewer-actor", role: "viewer")

      post "/api/v1/operations/failed-jobs/456/retry",
           params: { project_id: project.id, reason_template: "operator_confirmed_safe_retry" },
           headers: auth_headers("viewer-actor"),
           as: :json

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "POST /api/v1/operations/failed-jobs/:failed_job_id/discard" do
    it "returns safe validation errors from the operation service" do
      project = create(:project)
      authorize_project(project, actor_id: "admin-actor", role: "admin")
      stub_failed_job_operation(
        action: "discard",
        result: Operations::FailedJobOperationService::Result.new(
          success?: false,
          code: "failed_job_reason_template_invalid",
          message: "Failed job operation reason template is invalid.",
          http_status: :unprocessable_entity,
          details: { reason_template: "free_text" }
        )
      )

      post "/api/v1/operations/failed-jobs/456/discard",
           params: { project_id: project.id, reason_template: "free_text" },
           headers: auth_headers("admin-actor"),
           as: :json

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("failed_job_reason_template_invalid")
      expect(response.body).not_to include("raw exception")
    end
  end

  def stub_failed_job_operation(action:, result:)
    service = instance_double(Operations::FailedJobOperationService, call: result)
    allow(Operations::FailedJobOperationService).to receive(:new)
      .with(
        project: instance_of(Project),
        actor_id: "admin-actor",
        failed_job_id: "456",
        action: action,
        reason_template: instance_of(String)
      )
      .and_return(service)
  end
end
