require "rails_helper"

RSpec.describe "API V1 Jobs", type: :request do
  describe "GET /api/v1/jobs/:id" do
    it "returns a job" do
      job = create(:job)
      authorize_project(job.project, actor_id: "viewer-actor", role: "viewer")

      get "/api/v1/jobs/#{job.id}", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(job.id)
    end

    it "rejects job reads from another project" do
      job = create(:job)
      authorize_project(create(:project), actor_id: "other-admin", role: "admin")

      get "/api/v1/jobs/#{job.id}", headers: auth_headers("other-admin")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end
end
