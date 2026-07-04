require "rails_helper"

RSpec.describe "API V1 Conversation Summary Drafts", type: :request do
  describe "GET /api/v1/conversation-summary-drafts/:id" do
    it "returns a conversation summary draft" do
      draft = create(:conversation_summary_draft)

      get "/api/v1/conversation-summary-drafts/#{draft.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(draft.id)
    end
  end

  describe "PATCH /api/v1/conversation-summary-drafts/:id" do
    it "updates a draft after human review" do
      draft = create(:conversation_summary_draft)

      patch "/api/v1/conversation-summary-drafts/#{draft.id}", params: {
        summary: "レビュー後のDM整理サマリー",
        open_questions: ["保持期間を決める"]
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "summary")).to eq("レビュー後のDM整理サマリー")
      expect(body.dig("data", "open_questions")).to eq(["保持期間を決める"])
      expect(draft.conversation_import.project.audit_logs.last.action).to eq("conversation_summary_draft.updated")
    end
  end

  describe "POST /api/v1/conversation-summary-drafts/:id/approve" do
    it "approves a draft and its import" do
      draft = create(:conversation_summary_draft)

      post "/api/v1/conversation-summary-drafts/#{draft.id}/approve", params: {
        approval_note: "Issue候補化してよい",
        generate_downstream_candidates: true
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("approved")
      expect(draft.reload.status).to eq("approved")
      expect(draft.conversation_import.reload.status).to eq("approved")
      expect(draft.conversation_import.project.audit_logs.last.action).to eq("conversation_summary_draft.approved")
    end

    it "requires an approval note" do
      draft = create(:conversation_summary_draft)

      post "/api/v1/conversation-summary-drafts/#{draft.id}/approve", params: {}

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("approval_note_required")
      expect(draft.reload.status).to eq("draft")
      expect(draft.conversation_import.reload.status).to eq("draft")
    end
  end
end
