require "rails_helper"

RSpec.describe "API V1 Project Memberships", type: :request do
  describe "GET /api/v1/projects/:project_id/memberships" do
    it "lists active memberships for an owner" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "editor-actor", role: "editor")
      create(:project_membership, project: project, actor_id: "revoked-actor", role: "viewer", status: "revoked")

      get "/api/v1/projects/#{project.id}/memberships", headers: auth_headers("owner-actor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data").map { |item| item["actor_id"] }).to contain_exactly("owner-actor", "editor-actor")
      expect(body.dig("meta", "total_count")).to eq(2)
    end

    it "allows an admin to include revoked memberships" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "admin-actor", role: "admin")
      create(:project_membership, project: project, actor_id: "revoked-actor", role: "viewer", status: "revoked")

      get "/api/v1/projects/#{project.id}/memberships", params: { status: "all" }, headers: auth_headers("admin-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data").map { |item| item["actor_id"] }).to include("revoked-actor")
    end

    it "rejects non-admin members" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "viewer-actor", role: "viewer")

      get "/api/v1/projects/#{project.id}/memberships", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_membership_forbidden")
    end
  end

  describe "POST /api/v1/projects/:project_id/memberships" do
    it "allows an admin to create a non-owner membership and writes safe audit metadata" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "admin-actor", role: "admin")

      post "/api/v1/projects/#{project.id}/memberships", params: {
        actor_id: "new-editor",
        role: "editor"
      }, headers: auth_headers("admin-actor")

      expect(response).to have_http_status(:created)
      membership = ProjectMembership.find(JSON.parse(response.body).dig("data", "id"))
      expect(membership.actor_id).to eq("new-editor")
      expect(membership.role).to eq("editor")
      audit_log = project.audit_logs.order(:created_at).last
      expect(audit_log.action).to eq("project_membership.created")
      expect(audit_log.actor_id).to eq("admin-actor")
      expect(audit_log.metadata).to eq(
        "membership_id" => membership.id,
        "target_actor_id" => "new-editor",
        "role_after" => "editor",
        "status_after" => "active"
      )
    end

    it "allows only owners to create owner memberships" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "admin-actor", role: "admin")

      post "/api/v1/projects/#{project.id}/memberships", params: {
        actor_id: "new-owner",
        role: "owner"
      }, headers: auth_headers("admin-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_membership_owner_required")
      expect(project.project_memberships.find_by(actor_id: "new-owner")).to be_nil

      post "/api/v1/projects/#{project.id}/memberships", params: {
        actor_id: "new-owner",
        role: "owner"
      }, headers: auth_headers("owner-actor")

      expect(response).to have_http_status(:created)
      expect(project.project_memberships.find_by(actor_id: "new-owner").role).to eq("owner")
    end

    it "rejects duplicate or revoked existing actors" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "existing-actor", role: "viewer", status: "revoked")

      post "/api/v1/projects/#{project.id}/memberships", params: {
        actor_id: "existing-actor",
        role: "viewer"
      }, headers: auth_headers("owner-actor")

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_membership_already_exists")
    end
  end

  describe "PATCH /api/v1/projects/:project_id/memberships/:membership_id" do
    it "allows an admin to update a non-owner role" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "admin-actor", role: "admin")
      membership = create(:project_membership, project: project, actor_id: "editor-actor", role: "editor")

      patch "/api/v1/projects/#{project.id}/memberships/#{membership.id}", params: {
        role: "reviewer"
      }, headers: auth_headers("admin-actor")

      expect(response).to have_http_status(:ok)
      expect(membership.reload.role).to eq("reviewer")
      audit_log = project.audit_logs.order(:created_at).last
      expect(audit_log.action).to eq("project_membership.role_changed")
      expect(audit_log.metadata).to include(
        "membership_id" => membership.id,
        "target_actor_id" => "editor-actor",
        "role_before" => "editor",
        "role_after" => "reviewer"
      )
      expect(audit_log.metadata.to_json).not_to include("Authorization")
    end

    it "allows only owners to promote to owner or demote owners" do
      project = create(:project)
      owner = create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      create(:project_membership, project: project, actor_id: "second-owner", role: "owner")
      create(:project_membership, project: project, actor_id: "admin-actor", role: "admin")
      editor = create(:project_membership, project: project, actor_id: "editor-actor", role: "editor")

      patch "/api/v1/projects/#{project.id}/memberships/#{editor.id}", params: {
        role: "owner"
      }, headers: auth_headers("admin-actor")

      expect(response).to have_http_status(:forbidden)
      expect(editor.reload.role).to eq("editor")

      patch "/api/v1/projects/#{project.id}/memberships/#{owner.id}", params: {
        role: "admin"
      }, headers: auth_headers("admin-actor")

      expect(response).to have_http_status(:forbidden)
      expect(owner.reload.role).to eq("owner")
    end

    it "prevents demoting the last active owner" do
      project = create(:project)
      owner = create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")

      patch "/api/v1/projects/#{project.id}/memberships/#{owner.id}", params: {
        role: "admin"
      }, headers: auth_headers("owner-actor")

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("last_owner_required")
      expect(owner.reload.role).to eq("owner")
    end

    it "does not update memberships from another project" do
      project = create(:project)
      other_project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      other_membership = create(:project_membership, project: other_project, actor_id: "other-viewer", role: "viewer")

      patch "/api/v1/projects/#{project.id}/memberships/#{other_membership.id}", params: {
        role: "admin"
      }, headers: auth_headers("owner-actor")

      expect(response).to have_http_status(:not_found)
      expect(other_membership.reload.role).to eq("viewer")
    end
  end

  describe "DELETE /api/v1/projects/:project_id/memberships/:membership_id" do
    it "revokes a non-owner membership" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      membership = create(:project_membership, project: project, actor_id: "viewer-actor", role: "viewer")

      delete "/api/v1/projects/#{project.id}/memberships/#{membership.id}", headers: auth_headers("owner-actor")

      expect(response).to have_http_status(:no_content)
      expect(membership.reload.status).to eq("revoked")
      audit_log = project.audit_logs.order(:created_at).last
      expect(audit_log.action).to eq("project_membership.revoked")
      expect(audit_log.metadata).to include(
        "membership_id" => membership.id,
        "target_actor_id" => "viewer-actor",
        "status_before" => "active",
        "status_after" => "revoked"
      )
    end

    it "prevents revoking the last active owner" do
      project = create(:project)
      owner = create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")

      delete "/api/v1/projects/#{project.id}/memberships/#{owner.id}", headers: auth_headers("owner-actor")

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("last_owner_required")
      expect(owner.reload.status).to eq("active")
    end

    it "allows an owner to revoke one of multiple owners" do
      project = create(:project)
      create(:project_membership, project: project, actor_id: "owner-actor", role: "owner")
      second_owner = create(:project_membership, project: project, actor_id: "second-owner", role: "owner")

      delete "/api/v1/projects/#{project.id}/memberships/#{second_owner.id}", headers: auth_headers("owner-actor")

      expect(response).to have_http_status(:no_content)
      expect(second_owner.reload.status).to eq("revoked")
    end
  end
end
