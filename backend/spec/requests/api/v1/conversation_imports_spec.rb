require "rails_helper"

RSpec.describe "API V1 Conversation Imports", type: :request do
  describe "POST /api/v1/projects/:project_id/conversation-imports" do
    it "creates a manual Discord DM conversation import" do
      project = create(:project)

      post "/api/v1/projects/#{project.id}/conversation-imports", params: {
        source_type: "discord_dm_paste",
        title: "DM仕様相談",
        raw_text: "Kazuya: 決定: まず手動貼り付けで進める。",
        consent_confirmed: true,
        consent_statement_version: "dm-consent-v1",
        participants: [{ display_name: "Kazuya", role: "requester" }]
      }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("data", "source_type")).to eq("discord_dm_paste")
      expect(body.dig("data", "participants", 0, "display_name")).to eq("Kazuya")
      expect(project.audit_logs.last.action).to eq("conversation_import.created")
    end
  end

  describe "GET /api/v1/projects/:project_id/conversation-imports" do
    it "lists project conversation imports" do
      project = create(:project)
      create(:conversation_import, project: project, title: "DM A")

      get "/api/v1/projects/#{project.id}/conversation-imports"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", 0, "title")).to eq("DM A")
      expect(body.dig("meta", "total_count")).to eq(1)
    end
  end

  describe "POST /api/v1/conversation-imports/:id/scan" do
    it "marks a consented and redacted import as ready for AI" do
      conversation_import = create(:conversation_import, redacted_text: "決定: 手動貼り付けで進める。")

      post "/api/v1/conversation-imports/#{conversation_import.id}/scan"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "valid")).to eq(true)
      expect(body.dig("data", "next_action")).to eq("generate_summary")
      expect(body.dig("data", "conversation_import", "status")).to eq("ready_for_ai")
    end

    it "blocks missing consent and secret-like content before AI processing" do
      conversation_import = create(
        :conversation_import,
        consent_confirmed: false,
        raw_text: "password=hunter2 を使ってください。"
      )

      post "/api/v1/conversation-imports/#{conversation_import.id}/scan"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "valid")).to eq(false)
      expect(body.dig("data", "next_action")).to eq("edit_and_rescan")
      expect(body.dig("data", "blocked_reasons")).to include("consent_missing_blocked", "credential_blocked")
      expect(conversation_import.project.audit_logs.last.metadata.to_s).not_to include("hunter2")
    end
  end

  describe "PATCH /api/v1/conversation-imports/:id" do
    it "stales existing summary drafts and requires a rescan after text changes" do
      conversation_import = create(:conversation_import, status: "summary_draft", redacted_text: "決定: 旧方針で進める。")
      draft = create(:conversation_summary_draft, conversation_import: conversation_import, status: "draft")

      patch "/api/v1/conversation-imports/#{conversation_import.id}", params: {
        redacted_text: "決定: 新方針で進める。"
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("draft")
      expect(conversation_import.reload.status).to eq("draft")
      expect(conversation_import.last_scanned_at).to be_nil
      expect(draft.reload.status).to eq("stale")

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary"

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_not_ready_for_ai")
    end
  end

  describe "POST /api/v1/conversation-imports/:id/generate-summary" do
    it "generates a conversation summary draft after scan" do
      conversation_import = create(:conversation_import, status: "ready_for_ai")

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary"

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "job", "status")).to eq("succeeded")
      expect(body.dig("data", "conversation_summary_draft", "summary")).to include("DM整理は手動貼り付け")
      expect(conversation_import.reload.status).to eq("summary_draft")
      expect(conversation_import.project.audit_logs.last.action).to eq("conversation_summary_draft.generated")
    end

    it "uses redacted text for summary generation" do
      conversation_import = create(
        :conversation_import,
        status: "ready_for_ai",
        raw_text: "password=hunter2 を使ってください。",
        redacted_text: "認証情報は伏字化済みです。決定: 手動貼り付けで進める。"
      )

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary"

      expect(response).to have_http_status(:accepted)
      expect(response.body).not_to include("hunter2")
      expect(response.body).not_to include("password=")
      expect(JSON.parse(response.body).dig("data", "conversation_summary_draft", "summary")).to include("伏字化済み")
    end

    it "requires scan before summary generation" do
      conversation_import = create(:conversation_import, status: "draft")

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary"

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("conversation_import_not_ready_for_ai")
      expect(Job.last.status).to eq("failed")
    end
  end
end
