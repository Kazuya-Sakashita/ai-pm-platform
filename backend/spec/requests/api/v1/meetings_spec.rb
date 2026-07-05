require "rails_helper"

RSpec.describe "API V1 Meetings", type: :request do
  describe "POST /api/v1/projects/:project_id/meetings" do
    it "creates a meeting" do
      project = create(:project)
      authorize_project(project)

      post "/api/v1/projects/#{project.id}/meetings", params: {
        title: "Planning",
        source_type: "manual",
        raw_text: "Ship a narrow backend slice.",
        participants: ["PM", "Tech Lead"]
      }, headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("data", "project_id")).to eq(project.id)
      expect(project.audit_logs.last.action).to eq("meeting.created")
      expect(project.audit_logs.last.actor_id).to eq("dm-editor")
    end

    it "requires authentication before creating a meeting" do
      project = create(:project)

      post "/api/v1/projects/#{project.id}/meetings", params: {
        title: "Planning",
        source_type: "manual",
        raw_text: "Ship a narrow backend slice."
      }

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("authentication_required")
    end

    it "rejects meeting creation by read-only members" do
      project = create(:project)
      authorize_project(project, actor_id: "viewer-actor", role: "viewer")

      post "/api/v1/projects/#{project.id}/meetings", params: {
        title: "Planning",
        source_type: "manual",
        raw_text: "Ship a narrow backend slice."
      }, headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "GET /api/v1/projects/:project_id/meetings" do
    it "lists project meetings" do
      project = create(:project)
      authorize_project(project, actor_id: "viewer-actor", role: "viewer")
      create(:meeting, project: project, title: "Kickoff")
      create(:meeting, project: create(:project), title: "Hidden")

      get "/api/v1/projects/#{project.id}/meetings", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", 0, "title")).to eq("Kickoff")
    end

    it "rejects non-members" do
      project = create(:project)
      create(:meeting, project: project, title: "Kickoff")

      get "/api/v1/projects/#{project.id}/meetings", headers: auth_headers("outsider")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "GET /api/v1/meetings/:id" do
    it "rejects cross-project access" do
      meeting = create(:meeting)
      authorize_project(create(:project), actor_id: "other-project-admin", role: "admin")

      get "/api/v1/meetings/#{meeting.id}", headers: auth_headers("other-project-admin")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end
end
