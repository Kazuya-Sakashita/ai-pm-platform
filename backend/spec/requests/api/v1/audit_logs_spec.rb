require "rails_helper"

RSpec.describe "API V1 Audit Logs", type: :request do
  describe "GET /api/v1/projects/:project_id/audit-logs" do
    it "lists project audit logs" do
      project = create(:project)
      AuditLog.record!(project: project, action: "project.created", target: project)

      get "/api/v1/projects/#{project.id}/audit-logs"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", 0, "action")).to eq("project.created")
    end
  end
end
