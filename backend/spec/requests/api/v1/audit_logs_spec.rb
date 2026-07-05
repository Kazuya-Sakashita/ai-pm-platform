require "rails_helper"

RSpec.describe "API V1 Audit Logs", type: :request do
  describe "GET /api/v1/projects/:project_id/audit-logs" do
    it "lists project audit logs" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "auditor-actor", role: "auditor")
      AuditLog.record!(project: project, action: "project.created", target: project)

      get "/api/v1/projects/#{project.id}/audit-logs", headers: auth_headers("auditor-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", 0, "action")).to eq("project.created")
    end

    it "requires project read access" do
      project = create(:project)
      other_project = create(:project)
      create(:project_membership, project: other_project, actor_id: "other-admin", role: "admin")
      AuditLog.record!(project: project, action: "project.created", target: project)

      get "/api/v1/projects/#{project.id}/audit-logs", headers: auth_headers("other-admin")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
      expect(response.body).not_to include("project.created")
    end
  end
end
