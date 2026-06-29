require "rails_helper"

RSpec.describe "API V1 Projects", type: :request do
  describe "GET /api/v1/projects" do
    it "lists projects" do
      create(:project, name: "ReviewOps")

      get "/api/v1/projects"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", 0, "name")).to eq("ReviewOps")
      expect(body.dig("meta", "total_count")).to eq(1)
    end
  end

  describe "POST /api/v1/projects" do
    it "creates a project and audit log" do
      post "/api/v1/projects", params: {
        name: "AI PM",
        description: "Automated project manager",
        github_repo: "Kazuya-Sakashita/ai-pm-platform"
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      project = Project.find(body.dig("data", "id"))
      expect(project.audit_logs.last.action).to eq("project.created")
    end
  end

  describe "PATCH /api/v1/projects/:id" do
    it "updates a project" do
      project = create(:project)

      patch "/api/v1/projects/#{project.id}", params: { name: "Updated" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "name")).to eq("Updated")
    end
  end

  describe "DELETE /api/v1/projects/:id" do
    it "archives a project" do
      project = create(:project)

      delete "/api/v1/projects/#{project.id}"

      expect(response).to have_http_status(:no_content)
      expect(project.reload.status).to eq("archived")
    end
  end
end
