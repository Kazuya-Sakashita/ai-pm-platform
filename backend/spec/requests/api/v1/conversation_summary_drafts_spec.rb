require "rails_helper"

RSpec.describe "API V1 Conversation Summary Drafts", type: :request do
  describe "GET /api/v1/conversation-summary-drafts/:id" do
    it "returns a conversation summary draft" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, role: "viewer")

      get "/api/v1/conversation-summary-drafts/#{draft.id}", headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(draft.id)
    end

    it "does not keep sensitive draft body in plaintext database columns" do
      sensitive_text = "社外秘ロードマップ: Project Aurora"
      draft = create(
        :conversation_summary_draft,
        summary: sensitive_text,
        decisions: [{ text: sensitive_text, confidence: 0.8 }],
        source_quotes: [{ id: "q1", quote: sensitive_text }]
      )
      authorize_project(draft.conversation_import.project, role: "viewer")

      get "/api/v1/conversation-summary-drafts/#{draft.id}", headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(sensitive_text)
      stored = stored_summary_draft_row(draft)
      expect(stored.fetch("summary")).to eq(ConversationSummaryDraft::STORED_SUMMARY_PLACEHOLDER)
      expect(stored.fetch("decisions")).to eq("[]")
      expect(stored.fetch("source_quotes")).to eq("[]")
      expect(stored.values.compact.join(" ")).not_to include(sensitive_text)
      expect(draft.reload.summary).to eq(sensitive_text)
    end

    it "does not expose sensitive body after anonymization" do
      sensitive_text = "削除対象の秘密メモ"
      draft = create(
        :conversation_summary_draft,
        summary: sensitive_text,
        open_questions: [sensitive_text],
        source_quotes: [{ id: "q1", quote: sensitive_text }]
      )
      authorize_project(draft.conversation_import.project, role: "viewer")

      draft.anonymize!
      get "/api/v1/conversation-summary-drafts/#{draft.id}", headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(sensitive_text)
      body = JSON.parse(response.body)
      expect(body.dig("data", "summary")).to eq(ConversationSummaryDraft::ANONYMIZED_SUMMARY)
      expect(body.dig("data", "open_questions")).to eq([])
      expect(body.dig("data", "source_quotes")).to eq([])
      expect(stored_summary_draft_row(draft).values.compact.join(" ")).not_to include(sensitive_text)
    end
  end

  describe "PATCH /api/v1/conversation-summary-drafts/:id" do
    it "updates a draft after human review" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, role: "reviewer")

      patch "/api/v1/conversation-summary-drafts/#{draft.id}", params: {
        summary: "レビュー後のDM整理サマリー",
        open_questions: ["保持期間を決める"]
      }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "summary")).to eq("レビュー後のDM整理サマリー")
      expect(body.dig("data", "open_questions")).to eq(["保持期間を決める"])
      expect(draft.conversation_import.project.audit_logs.last.action).to eq("conversation_summary_draft.updated")
      expect(draft.conversation_import.project.audit_logs.last.actor_id).to eq("dm-editor")
      expect(stored_summary_draft_row(draft).values.compact.join(" ")).not_to include("レビュー後のDM整理サマリー")
    end

    it "rejects updates for approved drafts" do
      draft = create(:conversation_summary_draft, status: "approved")
      authorize_project(draft.conversation_import.project, role: "reviewer")

      patch "/api/v1/conversation-summary-drafts/#{draft.id}", params: {
        summary: "承認後に書き換えない"
      }, headers: actor_headers

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("summary_draft_not_editable")
      expect(draft.reload.summary).not_to eq("承認後に書き換えない")
    end

    it "rejects direct status changes to approved" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, role: "reviewer")

      patch "/api/v1/conversation-summary-drafts/#{draft.id}", params: {
        status: "approved"
      }, headers: actor_headers

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("summary_draft_status_not_editable")
      expect(draft.reload.status).to eq("draft")
    end
  end

  describe "POST /api/v1/conversation-summary-drafts/:id/approve" do
    it "approves a draft and its import" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, role: "reviewer")

      post "/api/v1/conversation-summary-drafts/#{draft.id}/approve", params: {
        approval_note: "Issue候補化してよい",
        generate_downstream_candidates: true
      }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("approved")
      expect(draft.reload.status).to eq("approved")
      expect(draft.conversation_import.reload.status).to eq("approved")
      expect(draft.conversation_import.project.audit_logs.last.action).to eq("conversation_summary_draft.approved")
      expect(draft.conversation_import.project.audit_logs.last.actor_id).to eq("dm-editor")
    end

    it "requires an approval note" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, role: "reviewer")

      post "/api/v1/conversation-summary-drafts/#{draft.id}/approve", params: {}, headers: actor_headers

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("approval_note_required")
      expect(draft.reload.status).to eq("draft")
      expect(draft.conversation_import.reload.status).to eq("draft")
    end

    it "rejects an editor without approval permission" do
      draft = create(:conversation_summary_draft)
      authorize_project(draft.conversation_import.project, role: "editor")

      post "/api/v1/conversation-summary-drafts/#{draft.id}/approve", params: {
        approval_note: "editorでは承認しない"
      }, headers: actor_headers

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_forbidden")
      expect(draft.reload.status).to eq("draft")
    end

    it "rejects approval for stale drafts" do
      draft = create(:conversation_summary_draft, status: "stale")
      authorize_project(draft.conversation_import.project, role: "reviewer")

      post "/api/v1/conversation-summary-drafts/#{draft.id}/approve", params: {
        approval_note: "古いドラフトは承認しない"
      }, headers: actor_headers

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("summary_draft_not_editable")
      expect(draft.reload.status).to eq("stale")
    end
  end

  def stored_summary_draft_row(draft)
    ConversationSummaryDraft.connection.exec_query(<<~SQL.squish).first
      SELECT
        summary,
        decisions::text AS decisions,
        open_questions::text AS open_questions,
        action_items::text AS action_items,
        issue_candidates::text AS issue_candidates,
        requirement_candidates::text AS requirement_candidates,
        risks::text AS risks,
        participants::text AS participants,
        source_quotes::text AS source_quotes,
        validation_errors::text AS validation_errors,
        protected_payload
      FROM conversation_summary_drafts
      WHERE id = #{ConversationSummaryDraft.connection.quote(draft.id)}
    SQL
  end

  def actor_headers(actor_id = "dm-editor", **options)
    auth_headers(actor_id, **options)
  end

  def authorize_project(project, actor_id: "dm-editor", role: "editor")
    create(:project_membership, project: project, actor_id: actor_id, role: role)
  end
end
