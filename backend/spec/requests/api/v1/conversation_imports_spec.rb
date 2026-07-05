require "rails_helper"

RSpec.describe "API V1 Conversation Imports", type: :request do
  describe "POST /api/v1/projects/:project_id/conversation-imports" do
    it "creates a manual Discord DM conversation import" do
      project = create(:project)
      authorize_project(project)

      post "/api/v1/projects/#{project.id}/conversation-imports", params: {
        source_type: "discord_dm_paste",
        title: "DM仕様相談",
        raw_text: "Kazuya: 決定: まず手動貼り付けで進める。",
        consent_confirmed: true,
        consent_statement_version: "dm-consent-v1",
        participants: [{ display_name: "Kazuya", role: "requester" }]
      }, headers: actor_headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig("data", "source_type")).to eq("discord_dm_paste")
      expect(body.dig("data", "participants", 0, "display_name")).to eq("Kazuya")
      expect(body.dig("data", "raw_text_retention_expires_at")).to be_present
      expect(body.dig("data", "retention_expires_at")).to be_present
      expect(project.audit_logs.last.action).to eq("conversation_import.created")
      expect(project.audit_logs.last.actor_id).to eq("dm-editor")

      conversation_import = ConversationImport.find(body.dig("data", "id"))
      stored_raw_text = ConversationImport.connection.select_value(
        "SELECT raw_text FROM conversation_imports WHERE id = #{ConversationImport.connection.quote(conversation_import.id)}"
      )
      expect(stored_raw_text).not_to include("まず手動貼り付け")
      expect(conversation_import.raw_text).to include("まず手動貼り付け")
    end
  end

  describe "GET /api/v1/projects/:project_id/conversation-imports" do
    it "lists project conversation imports" do
      project = create(:project)
      authorize_project(project, role: "viewer")
      create(:conversation_import, project: project, title: "DM A")

      get "/api/v1/projects/#{project.id}/conversation-imports", headers: actor_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", 0, "title")).to eq("DM A")
      expect(body.dig("meta", "total_count")).to eq(1)
    end
  end

  describe "POST /api/v1/conversation-imports/:id/scan" do
    it "marks a consented and redacted import as ready for AI" do
      conversation_import = create(:conversation_import, redacted_text: "決定: 手動貼り付けで進める。")
      authorize_project(conversation_import.project)

      post "/api/v1/conversation-imports/#{conversation_import.id}/scan", headers: actor_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "valid")).to eq(true)
      expect(body.dig("data", "next_action")).to eq("generate_summary")
      expect(body.dig("data", "conversation_import", "status")).to eq("ready_for_ai")
      expect(conversation_import.project.audit_logs.last.actor_id).to eq("dm-editor")
    end

    it "blocks missing consent and secret-like content before AI processing" do
      conversation_import = create(
        :conversation_import,
        consent_confirmed: false,
        raw_text: "password=hunter2 を使ってください。"
      )
      authorize_project(conversation_import.project)

      post "/api/v1/conversation-imports/#{conversation_import.id}/scan", headers: actor_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "valid")).to eq(false)
      expect(body.dig("data", "next_action")).to eq("edit_and_rescan")
      expect(body.dig("data", "blocked_reasons")).to include("consent_missing_blocked", "credential_blocked")
      expect(conversation_import.project.audit_logs.last.metadata.to_s).not_to include("hunter2")
    end

    it "blocks PII, credential, financial, and legal content with safe redaction suggestions" do
      conversation_import = create(
        :conversation_import,
        raw_text: [
          "連絡先は customer@example.com と 090-1234-5678 です。",
          "送付先は東京都渋谷区神南1-2-3です。",
          "確認URLは https://example.com/callback?token=abc1234567890secret です。",
          "請求書とNDAの確認もお願いします。"
        ].join("\n")
      )
      authorize_project(conversation_import.project)

      post "/api/v1/conversation-imports/#{conversation_import.id}/scan", headers: actor_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "valid")).to eq(false)
      expect(body.dig("data", "next_action")).to eq("edit_and_rescan")
      expect(body.dig("data", "conversation_import", "status")).to eq("blocked")
      expect(body.dig("data", "blocked_reasons")).to include("personal_data_blocked", "credential_blocked", "financial_blocked", "legal_blocked")

      safety_flags = body.dig("data", "safety_flags")
      expect(safety_flags.map { |flag| flag.fetch("type") }).to include("personal_data", "credential", "financial", "legal")
      expect(safety_flags.map { |flag| flag.fetch("location_hint") }).to include("メールアドレス", "電話番号", "住所", "URLクエリ", "金融情報", "法務情報")
      expect(safety_flags.to_s).not_to include("customer@example.com", "090-1234-5678", "abc1234567890secret")

      redaction_suggestions = body.dig("data", "redaction_suggestions")
      expect(redaction_suggestions.map { |suggestion| suggestion.fetch("suggested_replacement") }).to include(
        "[EMAIL_REDACTED]",
        "[PHONE_REDACTED]",
        "[ADDRESS_REDACTED]",
        "[URL_WITH_TOKEN_REDACTED]",
        "[FINANCIAL_INFO_REDACTED]",
        "[LEGAL_INFO_REDACTED]"
      )
      expect(redaction_suggestions.to_s).not_to include("customer@example.com", "090-1234-5678", "abc1234567890secret")
      expect(conversation_import.project.audit_logs.last.metadata.to_s).not_to include("customer@example.com", "090-1234-5678", "abc1234567890secret")

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary", headers: actor_headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_not_ready_for_ai")
    end
  end

  describe "PATCH /api/v1/conversation-imports/:id" do
    it "stales existing summary drafts and requires a rescan after text changes" do
      conversation_import = create(:conversation_import, status: "summary_draft", redacted_text: "決定: 旧方針で進める。")
      draft = create(:conversation_summary_draft, conversation_import: conversation_import, status: "draft")
      authorize_project(conversation_import.project)

      patch "/api/v1/conversation-imports/#{conversation_import.id}", params: {
        redacted_text: "決定: 新方針で進める。"
      }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("draft")
      expect(conversation_import.reload.status).to eq("draft")
      expect(conversation_import.last_scanned_at).to be_nil
      expect(draft.reload.status).to eq("stale")

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary", headers: actor_headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_not_ready_for_ai")
    end
  end

  describe "DELETE /api/v1/conversation-imports/:id" do
    it "anonymizes retained text, summary drafts, and records safe audit metadata" do
      conversation_import = create(
        :conversation_import,
        raw_text: "password=hunter2 を使ってください。",
        redacted_text: "認証情報はマスキング済みです。"
      )
      draft = create(
        :conversation_summary_draft,
        conversation_import: conversation_import,
        summary: "password=hunter2 を含む要約",
        decisions: [{ text: "password=hunter2 を使う", confidence: 0.9 }],
        source_quotes: [{ id: "q1", quote: "password=hunter2" }]
      )
      authorize_project(conversation_import.project, role: "admin")

      delete "/api/v1/conversation-imports/#{conversation_import.id}", headers: actor_headers

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_blank

      conversation_import.reload
      expect(conversation_import.status).to eq("archived")
      expect(conversation_import.raw_text).to eq(ConversationImport::ANONYMIZED_TEXT)
      expect(conversation_import.redacted_text).to be_nil
      expect(conversation_import.participants).to eq([])
      expect(conversation_import.anonymized_at).to be_present
      expect(conversation_import.raw_text_purged_at).to be_present

      draft.reload
      expect(draft.status).to eq("rejected")
      expect(draft.summary).to eq(ConversationSummaryDraft::ANONYMIZED_SUMMARY)
      expect(draft.decisions).to eq([])
      expect(draft.source_quotes).to eq([])

      audit_log = conversation_import.project.audit_logs.last
      expect(audit_log.action).to eq("conversation_import.anonymized")
      expect(audit_log.actor_id).to eq("dm-editor")
      expect(audit_log.metadata.to_s).not_to include("hunter2")

      stored_raw_text = ConversationImport.connection.select_value(
        "SELECT raw_text FROM conversation_imports WHERE id = #{ConversationImport.connection.quote(conversation_import.id)}"
      )
      expect(stored_raw_text).not_to include("hunter2")

      post "/api/v1/conversation-imports/#{conversation_import.id}/scan", headers: actor_headers
      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_anonymized")
    end
  end

  describe "ConversationImportRetentionJob" do
    it "purges expired raw text and anonymizes imports past full retention" do
      raw_expired_import = create(
        :conversation_import,
        raw_text: "個人情報を含む原文",
        redacted_text: "マスキング済み本文",
        raw_text_retention_expires_at: 1.minute.ago,
        retention_expires_at: 1.day.from_now
      )
      full_expired_import = create(
        :conversation_import,
        raw_text: "長期保持期限切れの原文",
        redacted_text: "長期保持期限切れの本文",
        raw_text_retention_expires_at: 1.day.from_now,
        retention_expires_at: 1.minute.ago
      )
      create(:conversation_summary_draft, conversation_import: full_expired_import, summary: "期限切れの整理内容")

      result = ConversationImportRetentionJob.perform_now(10)

      expect(result.raw_text_purged_count).to eq(1)
      expect(result.anonymized_count).to eq(1)
      expect(raw_expired_import.reload.raw_text).to eq(ConversationImport::RAW_TEXT_PURGED_PLACEHOLDER)
      expect(raw_expired_import.redacted_text).to eq("マスキング済み本文")
      expect(full_expired_import.reload.status).to eq("archived")
      expect(full_expired_import.conversation_summary_drafts.first.summary).to eq(ConversationSummaryDraft::ANONYMIZED_SUMMARY)
      expect(AuditLog.where(action: "conversation_import.raw_text_purged").last.metadata.to_s).not_to include("個人情報")
      expect(AuditLog.where(action: "conversation_import.anonymized").last.metadata.to_s).not_to include("長期保持期限切れ")
    end
  end

  describe "POST /api/v1/conversation-imports/:id/generate-summary" do
    it "generates a conversation summary draft after scan" do
      conversation_import = create(:conversation_import, status: "ready_for_ai")
      authorize_project(conversation_import.project)

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary", headers: actor_headers

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      expect(body.dig("data", "job", "status")).to eq("succeeded")
      expect(body.dig("data", "conversation_summary_draft", "summary")).to include("DM整理は手動貼り付け")
      expect(conversation_import.reload.status).to eq("summary_draft")
      expect(conversation_import.project.audit_logs.last.action).to eq("conversation_summary_draft.generated")
      expect(conversation_import.project.audit_logs.last.actor_id).to eq("dm-editor")
    end

    it "uses redacted text for summary generation" do
      conversation_import = create(
        :conversation_import,
        status: "ready_for_ai",
        raw_text: "password=hunter2 を使ってください。",
        redacted_text: "認証情報は伏字化済みです。決定: 手動貼り付けで進める。"
      )
      authorize_project(conversation_import.project)

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary", headers: actor_headers

      expect(response).to have_http_status(:accepted)
      expect(response.body).not_to include("hunter2")
      expect(response.body).not_to include("password=")
      expect(JSON.parse(response.body).dig("data", "conversation_summary_draft", "summary")).to include("伏字化済み")
    end

    it "requires scan before summary generation" do
      conversation_import = create(:conversation_import, status: "draft")
      authorize_project(conversation_import.project)

      post "/api/v1/conversation-imports/#{conversation_import.id}/generate-summary", headers: actor_headers

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("conversation_import_not_ready_for_ai")
      expect(Job.last.status).to eq("failed")
    end
  end

  describe "project membership policy" do
    it "requires an actor header for DM access" do
      conversation_import = create(:conversation_import)

      get "/api/v1/conversation-imports/#{conversation_import.id}"

      expect(response).to have_http_status(:unauthorized)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_actor_required")
      expect(response.body).not_to include(conversation_import.raw_text)
    end

    it "rejects a non-member without exposing DM body" do
      conversation_import = create(:conversation_import, raw_text: "非memberには見せないDM本文")

      get "/api/v1/conversation-imports/#{conversation_import.id}", headers: actor_headers("outsider")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_forbidden")
      expect(response.body).not_to include("非memberには見せないDM本文")
    end

    it "rejects a member of another project" do
      conversation_import = create(:conversation_import)
      authorize_project(create(:project), actor_id: "cross-project-admin", role: "admin")

      post "/api/v1/conversation-imports/#{conversation_import.id}/scan", headers: actor_headers("cross-project-admin")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_forbidden")
    end

    it "rejects a readonly member for DM mutations" do
      conversation_import = create(:conversation_import)
      authorize_project(conversation_import.project, actor_id: "readonly-user", role: "viewer")

      patch "/api/v1/conversation-imports/#{conversation_import.id}", params: {
        title: "viewer should not edit"
      }, headers: actor_headers("readonly-user")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("conversation_import_forbidden")
    end
  end

  def actor_headers(actor_id = "dm-editor")
    { "X-Actor-Id" => actor_id }
  end

  def authorize_project(project, actor_id: "dm-editor", role: "editor")
    create(:project_membership, project: project, actor_id: actor_id, role: role)
  end
end
