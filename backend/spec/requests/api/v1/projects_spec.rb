require "rails_helper"

RSpec.describe "API V1 Projects", type: :request do
  describe "GET /api/v1/projects" do
    it "lists projects for the authenticated actor" do
      visible_project = create(:project, name: "ReviewOps")
      hidden_project = create(:project, name: "Hidden")
      create(:project_membership, project: visible_project, actor_id: "project-owner", role: "owner")
      create(:project_membership, project: hidden_project, actor_id: "other-owner", role: "owner")

      get "/api/v1/projects", headers: auth_headers("project-owner")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", 0, "name")).to eq("ReviewOps")
      expect(body.dig("meta", "total_count")).to eq(1)
    end

    it "requires authentication" do
      get "/api/v1/projects"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("authentication_required")
    end
  end

  describe "POST /api/v1/projects" do
    it "creates a project and audit log" do
      post "/api/v1/projects", params: {
        name: "AI PM",
        description: "Automated project manager",
        github_repo: "Kazuya-Sakashita/ai-pm-platform"
      }, headers: auth_headers("project-owner")

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      project = Project.find(body.dig("data", "id"))
      expect(project.audit_logs.last.action).to eq("project.created")
      expect(project.audit_logs.last.actor_id).to eq("project-owner")
      expect(project.project_memberships.find_by(actor_id: "project-owner").role).to eq("owner")
    end
  end

  describe "PATCH /api/v1/projects/:id" do
    it "updates a project" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "project-owner", role: "owner")

      patch "/api/v1/projects/#{project.id}", params: { name: "Updated" }, headers: auth_headers("project-owner")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "name")).to eq("Updated")
    end

    it "rejects project updates by non-admin members" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "project-viewer", role: "viewer")

      patch "/api/v1/projects/#{project.id}", params: { name: "Updated" }, headers: auth_headers("project-viewer")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "DELETE /api/v1/projects/:id" do
    it "archives a project" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "project-admin", role: "admin")

      delete "/api/v1/projects/#{project.id}", headers: auth_headers("project-admin")

      expect(response).to have_http_status(:no_content)
      expect(project.reload.status).to eq("archived")
    end
  end
end
