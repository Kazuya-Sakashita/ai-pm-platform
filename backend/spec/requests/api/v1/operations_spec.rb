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
end
