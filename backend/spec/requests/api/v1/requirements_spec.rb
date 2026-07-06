require "rails_helper"

RSpec.describe "API V1 Requirements", type: :request do
  describe "POST /api/v1/minutes/:id/generate-requirement" do
    it "generates a requirement draft from approved minutes" do
      minutes = create(
        :minute,
        status: "approved",
        summary: "Discord minutes should become requirements.",
        decisions: [{ "text" => "Generate requirements after minutes approval." }],
        open_questions: ["Who reviews requirements?"],
        action_items: [{ "text" => "Add requirement editor.", "status" => "open" }]
      )
      authorize_project(minutes.meeting.project)

      post "/api/v1/minutes/#{minutes.id}/generate-requirement", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("data", "job_id"))
      requirement = Requirement.find(job.target_id)
      expect(job.status).to eq("succeeded")
      expect(job.target_type).to eq("requirement")
      expect(requirement.background).to include("Discord minutes")
      expect(requirement.functional_requirements).to include(/Generate requirements after minutes approval/)
      expect(requirement.open_questions).to include("Who reviews requirements?")
      expect(minutes.meeting.project.audit_logs.last.action).to eq("requirement.generated")
    end

    it "requires approved minutes before requirement generation" do
      minutes = create(:minute, status: "generated")
      authorize_project(minutes.meeting.project)

      post "/api/v1/minutes/#{minutes.id}/generate-requirement", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "status")).to eq("generated")
      expect(Job.where(target_type: "requirement")).to be_empty
    end

    it "requires authentication before checking minutes status" do
      minutes = create(:minute, status: "generated")

      post "/api/v1/minutes/#{minutes.id}/generate-requirement"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("authentication_required")
    end
  end

  describe "GET /api/v1/requirements/:id" do
    it "returns a requirement" do
      requirement = create(:requirement)
      authorize_project(requirement.minute.meeting.project, actor_id: "viewer-actor", role: "viewer")

      get "/api/v1/requirements/#{requirement.id}", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "id")).to eq(requirement.id)
      expect(body.dig("data", "generated_by_model")).to eq("deterministic-requirements-placeholder-v1")
    end
  end

  describe "PATCH /api/v1/requirements/:id" do
    it "updates an editable requirement draft" do
      requirement = create(:requirement)
      authorize_project(requirement.minute.meeting.project)

      patch "/api/v1/requirements/#{requirement.id}", params: {
        background: "Updated background",
        goal: "Updated goal",
        functional_requirements: ["FR-001: Updated functional requirement"],
        acceptance_criteria: ["Updated acceptance criterion"],
        open_questions: []
      }, headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "background")).to eq("Updated background")
      expect(body.dig("data", "functional_requirements")).to eq(["FR-001: Updated functional requirement"])
      expect(requirement.minute.meeting.project.audit_logs.last.action).to eq("requirement.updated")
    end

    it "rejects requirement updates by viewers" do
      requirement = create(:requirement)
      authorize_project(requirement.minute.meeting.project, actor_id: "viewer-actor", role: "viewer")

      patch "/api/v1/requirements/#{requirement.id}", params: { goal: "Viewer update" }, headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end

    it "承認済みRequirementのレビュー対象フィールドが変わる場合は承認状態を差し戻す" do
      requirement = create(
        :requirement,
        status: "approved",
        open_questions: [],
        approved_at: 1.hour.ago,
        approved_by: "reviewer-actor",
        approval_note: "承認済み"
      )
      authorize_project(requirement.minute.meeting.project)

      patch "/api/v1/requirements/#{requirement.id}", params: {
        goal: "承認後に変更した目的"
      }, headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("needs_changes")
      expect(body.dig("data", "approved_at")).to be_nil
      expect(body.dig("data", "approved_by")).to be_nil
      expect(body.dig("data", "approval_note")).to be_nil
      expect(requirement.reload.status).to eq("needs_changes")
      expect(requirement.approved_at).to be_nil
      expect(requirement.approved_by).to be_nil
      expect(requirement.approval_note).to be_nil
      expect(requirement.minute.meeting.project.audit_logs.last.metadata).to include(
        "approval_reset" => true,
        "changed_fields" => ["goal"]
      )
    end

    it "PATCHで直接statusを変更することを拒否する" do
      requirement = create(:requirement, open_questions: [])
      authorize_project(requirement.minute.meeting.project)

      patch "/api/v1/requirements/#{requirement.id}", params: {
        status: "needs_changes"
      }, headers: auth_headers("dm-editor")

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("requirement_direct_status_update_not_allowed")
      expect(requirement.reload.status).to eq("generated")
    end
  end

  describe "POST /api/v1/requirements/:id/approve" do
    it "approves a requirement when open questions are resolved" do
      requirement = create(:requirement, open_questions: [])
      authorize_project(requirement.minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/requirements/#{requirement.id}/approve", params: {
        approval_note: "未解決事項が解消され、実装工程へ進めます。"
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("approved")
      expect(body.dig("data", "approved_by")).to eq("reviewer-actor")
      expect(body.dig("data", "approved_at")).to be_present
      expect(body.dig("data", "approval_note")).to eq("未解決事項が解消され、実装工程へ進めます。")
      expect(requirement.reload.status).to eq("approved")
      expect(requirement.approved_by).to eq("reviewer-actor")
      expect(requirement.approved_at).to be_present
      expect(requirement.approval_note).to eq("未解決事項が解消され、実装工程へ進めます。")
      expect(requirement.minute.meeting.project.audit_logs.last.action).to eq("requirement.approved")
      expect(requirement.minute.meeting.project.audit_logs.last.metadata).to include("approval_note_present" => true)
    end

    it "承認コメントがない場合は承認を拒否する" do
      requirement = create(:requirement, open_questions: [])
      authorize_project(requirement.minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/requirements/#{requirement.id}/approve", params: {}, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("approval_note_required")
      expect(requirement.reload.status).to eq("generated")
      expect(requirement.approved_at).to be_nil
      expect(requirement.approved_by).to be_nil
      expect(requirement.approval_note).to be_nil
    end

    it "blocks approval when unresolved open questions remain" do
      requirement = create(:requirement, open_questions: ["Who owns final approval?"])
      authorize_project(requirement.minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/requirements/#{requirement.id}/approve", params: {
        approval_note: "未解決事項を確認しました。"
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "open_questions")).to eq(["Who owns final approval?"])
      expect(requirement.reload.status).to eq("generated")
    end

    it "Requirementレビューが未解決の場合は承認をブロックする" do
      requirement = create(:requirement, open_questions: [])
      review = create(:review, target_type: "requirement", target_id: requirement.id, status: "action_required")
      authorize_project(requirement.minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/requirements/#{requirement.id}/approve", params: {
        approval_note: "レビュー指摘の残存状態を確認しました。"
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "review_ids")).to eq([review.id])
      expect(body.dig("error", "details", "review_statuses")).to include(review.id => "action_required")
      expect(requirement.reload.status).to eq("generated")
    end

    it "期限切れのリスク受容レビューがある場合は承認をブロックする" do
      requirement = create(:requirement, open_questions: [])
      review = create(
        :review,
        target_type: "requirement",
        target_id: requirement.id,
        status: "accepted_risk",
        accepted_risk: {
          "reason" => "一時的な承認。",
          "residual_risk" => "期限後に再レビューが必要。",
          "approved_by" => "Kazuya Reviewer",
          "expires_at" => 1.day.ago.iso8601,
          "linked_issue_number" => "#3",
          "accepted_at" => 2.days.ago.iso8601
        }
      )
      authorize_project(requirement.minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/requirements/#{requirement.id}/approve", params: {
        approval_note: "期限切れリスク受容の残存状態を確認しました。"
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "expired_accepted_risk_review_ids")).to eq([review.id])
      expect(requirement.reload.status).to eq("generated")
    end

    it "rejects approval from cross-project admins" do
      requirement = create(:requirement, open_questions: [])
      authorize_project(create(:project), actor_id: "other-admin", role: "admin")

      post "/api/v1/requirements/#{requirement.id}/approve", params: {
        approval_note: "別プロジェクトからは承認できません。"
      }, headers: auth_headers("other-admin")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end
end
