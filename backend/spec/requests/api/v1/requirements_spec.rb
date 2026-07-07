require "rails_helper"

RSpec.describe "API V1 Requirements", type: :request do
  around do |example|
    with_env("REQUIREMENT_GENERATION_PROVIDER" => "deterministic", "OPENAI_API_KEY" => nil) do
      example.run
    end
  end

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

    it "generates requirements through the OpenAI provider when configured" do
      minutes = create(
        :minute,
        status: "approved",
        summary: "OpenAI providerでRequirementを生成する。",
        decisions: [{ "text" => "Requirement OpenAI providerを使う。" }]
      )
      authorize_project(minutes.meeting.project)
      provider = instance_double(
        RequirementGeneration::OpenaiProvider,
        generate: {
          status: "generated",
          background: "OpenAI generated background.",
          goal: "OpenAI generated goal.",
          functional_requirements: ["FR-001: Generate requirements through OpenAI."],
          acceptance_criteria: ["OpenAI providerでRequirementが保存される。"],
          generated_by_model: "gpt-test"
        }
      )
      allow(RequirementGeneration::OpenaiProvider).to receive(:new).and_return(provider)

      with_env("REQUIREMENT_GENERATION_PROVIDER" => "openai", "OPENAI_API_KEY" => "test-openai-key") do
        post "/api/v1/minutes/#{minutes.id}/generate-requirement", headers: auth_headers("dm-editor")
      end

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("data", "job_id"))
      requirement = Requirement.find(job.target_id)
      expect(job.status).to eq("succeeded")
      expect(requirement.background).to eq("OpenAI generated background.")
      expect(requirement.generated_by_model).to eq("gpt-test")
    end

    it "stores a failed job when OpenAI requirement provider is forced but not connected" do
      minutes = create(:minute, status: "approved")
      authorize_project(minutes.meeting.project)

      with_env("REQUIREMENT_GENERATION_PROVIDER" => "openai", "OPENAI_API_KEY" => nil) do
        post "/api/v1/minutes/#{minutes.id}/generate-requirement", headers: auth_headers("dm-editor")
      end

      expect(response).to have_http_status(:failed_dependency)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("error", "details", "job_id"))
      expect(job.status).to eq("failed")
      expect(job.error_code).to eq("integration_not_connected")
      expect(job.safe_error_detail).to eq("OpenAI API key is not configured.")
      expect(minutes.meeting.project.audit_logs.last.action).to eq("requirement.generation_failed")
    end

    it "stores a failed job with request metadata when the OpenAI provider fails" do
      minutes = create(:minute, status: "approved")
      authorize_project(minutes.meeting.project)
      provider = instance_double(RequirementGeneration::OpenaiProvider)
      allow(provider).to receive(:generate).and_raise(
        RequirementGeneration::ProviderError.new(
          code: "rate_limit_exceeded",
          message: "OpenAI request failed with HTTP 429",
          safe_detail: "OpenAI request was rate limited. Retry after the provider limit resets.",
          http_status: :too_many_requests,
          request_id: "req_requirement_rate"
        )
      )
      allow(RequirementGeneration::OpenaiProvider).to receive(:new).and_return(provider)

      with_env("REQUIREMENT_GENERATION_PROVIDER" => "openai", "OPENAI_API_KEY" => "test-openai-key") do
        post "/api/v1/minutes/#{minutes.id}/generate-requirement", headers: auth_headers("dm-editor")
      end

      expect(response).to have_http_status(:too_many_requests)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("error", "details", "job_id"))
      audit_log = minutes.meeting.project.audit_logs.last
      expect(job.status).to eq("failed")
      expect(job.error_code).to eq("rate_limit_exceeded")
      expect(job.safe_error_detail).to eq("OpenAI request was rate limited. Retry after the provider limit resets.")
      expect(body.dig("error", "details", "request_id")).to eq("req_requirement_rate")
      expect(audit_log.action).to eq("requirement.generation_failed")
      expect(audit_log.metadata).to include("request_id" => "req_requirement_rate", "provider_error_code" => "rate_limit_exceeded")
    end

    it "blocks sensitive requirement source before constructing the OpenAI provider" do
      minutes = create(:minute, status: "approved", summary: "password=super-secret-value を使う。")
      authorize_project(minutes.meeting.project)

      expect(RequirementGeneration::OpenaiProvider).not_to receive(:new)
      with_env("REQUIREMENT_GENERATION_PROVIDER" => "openai", "OPENAI_API_KEY" => "test-openai-key") do
        post "/api/v1/minutes/#{minutes.id}/generate-requirement", headers: auth_headers("dm-editor")
      end

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("error", "details", "job_id"))
      expect(body.dig("error", "code")).to eq("sensitive_content_blocked")
      expect(job.status).to eq("failed")
      expect(job.error_code).to eq("sensitive_content_blocked")
      expect(job.safe_error_detail).to eq("要件定義生成に使う議事録に機密性の高い内容が含まれています。AI生成前にレビューしてください。")
      expect(minutes.requirements).to be_empty
    end

    it "requires approved minutes before requirement generation" do
      minutes = create(:minute, status: "generated")
      authorize_project(minutes.meeting.project)

      post "/api/v1/minutes/#{minutes.id}/generate-requirement", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "status")).to eq("generated")
      expect(Job.where(project: minutes.meeting.project, target_type: "requirement")).to be_empty
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

  describe "GET /api/v1/requirements/:id/history" do
    it "Requirement更新履歴とレビュー履歴を時系列で返す" do
      requirement = create(:requirement)
      project = requirement.minute.meeting.project
      authorize_project(project, actor_id: "viewer-actor", role: "viewer")
      review = create(
        :review,
        target_type: "requirement",
        target_id: requirement.id,
        status: "resolved",
        reviewer_role: "Product Manager"
      )
      requested_review_event = ReviewStateEvent.create!(
        review: review,
        project: project,
        target_type: "requirement",
        target_id: requirement.id,
        event_type: "review_requested",
        from_status: nil,
        to_status: "open",
        actor_id: "reviewer-actor",
        issue_numbers: ["ISSUE-050"],
        occurred_at: 2.hours.ago
      )
      resolved_review_event = ReviewStateEvent.create!(
        review: review,
        project: project,
        target_type: "requirement",
        target_id: requirement.id,
        event_type: "review_resolved",
        from_status: "open",
        to_status: "resolved",
        actor_id: "reviewer-actor",
        reason_code: "review_resolved",
        reason_summary: "確認済み",
        issue_numbers: ["ISSUE-050"],
        occurred_at: 1.hour.ago
      )
      AuditLog.record!(
        project: project,
        action: "requirement.updated",
        target: requirement,
        actor_id: "dm-editor",
        metadata: {
          changed_fields: ["goal"],
          field_changes: [
            {
              field: "goal",
              before: { item_count: 1, redacted: false, preview: "旧目的" },
              after: { item_count: 1, redacted: false, preview: "新目的" }
            }
          ],
          approval_reset: true,
          stale_issue_draft_count: 1,
          stale_open_api_draft_count: 1
        }
      )

      get "/api/v1/requirements/#{requirement.id}/history", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      event_types = body["data"].map { |item| item["event_type"] }
      expect(event_types).to include("updated", "review_requested", "review_resolved")
      updated_event = body["data"].find { |item| item["event_type"] == "updated" }
      requested_event = body["data"].find { |item| item["event_type"] == "review_requested" }
      resolved_event = body["data"].find { |item| item["event_type"] == "review_resolved" }

      expect(updated_event).to include(
        "source_type" => "audit_log",
        "title" => "要件定義を更新",
        "actor_id" => "dm-editor",
        "changed_fields" => ["goal"],
        "approval_reset" => true,
        "stale_issue_draft_count" => 1,
        "stale_open_api_draft_count" => 1
      )
      expect(updated_event.dig("changes", 0, "before", "preview")).to eq("旧目的")
      expect(updated_event.dig("changes", 0, "after", "preview")).to eq("新目的")
      expect(requested_event).to include(
        "id" => requested_review_event.id,
        "source_type" => "review_event",
        "actor_id" => "reviewer-actor",
        "reviewer_role" => "Product Manager",
        "review_status" => "open",
        "to_status" => "open"
      )
      expect(resolved_event).to include(
        "id" => resolved_review_event.id,
        "source_type" => "review_event",
        "actor_id" => "reviewer-actor",
        "reviewer_role" => "Product Manager",
        "review_status" => "resolved",
        "from_status" => "open",
        "to_status" => "resolved",
        "reason_summary" => "確認済み",
        "issue_numbers" => ["ISSUE-050"]
      )
    end

    it "secretを含む差分本文を履歴APIへ返さない" do
      requirement = create(:requirement)
      project = requirement.minute.meeting.project
      authorize_project(project, actor_id: "viewer-actor", role: "viewer")
      AuditLog.record!(
        project: project,
        action: "requirement.updated",
        target: requirement,
        actor_id: "dm-editor",
        metadata: {
          changed_fields: ["goal"],
          field_changes: [
            {
              field: "goal",
              before: { item_count: 1, redacted: false, preview: "旧目的" },
              after: {
                item_count: 1,
                redacted: true,
                preview: "機密情報を含むため非表示",
                finding_categories: ["credential"]
              }
            }
          ]
        }
      )

      get "/api/v1/requirements/#{requirement.id}/history", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.to_s).to include("機密情報を含むため非表示", "credential")
      expect(body.to_s).not_to include("api_key")
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
      issue_draft = create(:issue_draft, requirement: requirement, status: "approved")
      open_api_draft = create(:open_api_draft, requirement: requirement, status: "approved")

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
      expect(issue_draft.reload.status).to eq("stale")
      expect(open_api_draft.reload.status).to eq("stale")
      expect(requirement.minute.meeting.project.audit_logs.last.metadata).to include(
        "approval_reset" => true,
        "changed_fields" => ["goal"],
        "field_changes" => [
          hash_including(
            "field" => "goal",
            "before" => hash_including("redacted" => false),
            "after" => hash_including("preview" => "承認後に変更した目的")
          )
        ],
        "stale_issue_draft_ids" => [issue_draft.id],
        "stale_issue_draft_count" => 1,
        "stale_open_api_draft_ids" => [open_api_draft.id],
        "stale_open_api_draft_count" => 1
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
