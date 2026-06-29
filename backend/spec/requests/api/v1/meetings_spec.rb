require "rails_helper"

RSpec.describe "API V1 Meetings", type: :request do
  describe "POST /api/v1/projects/:project_id/meetings" do
    it "creates a meeting" do
      project = create(:project)

      post "/api/v1/projects/#{project.id}/meetings", params: {
        title: "Planning",
        source_type: "manual",
        raw_text: "Ship a narrow backend slice.",
        participants: ["PM", "Tech Lead"]
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("data", "project_id")).to eq(project.id)
      expect(project.audit_logs.last.action).to eq("meeting.created")
    end
  end

  describe "GET /api/v1/projects/:project_id/meetings" do
    it "lists project meetings" do
      project = create(:project)
      create(:meeting, project: project, title: "Kickoff")

      get "/api/v1/projects/#{project.id}/meetings"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", 0, "title")).to eq("Kickoff")
    end
  end
end
