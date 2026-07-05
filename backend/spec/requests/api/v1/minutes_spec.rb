require "rails_helper"

RSpec.describe "API V1 Minutes", type: :request do
  around do |example|
    original_provider = ENV["MINUTES_GENERATION_PROVIDER"]
    original_api_key = ENV["OPENAI_API_KEY"]
    ENV["MINUTES_GENERATION_PROVIDER"] = "deterministic"
    ENV.delete("OPENAI_API_KEY")
    example.run
  ensure
    ENV["MINUTES_GENERATION_PROVIDER"] = original_provider
    ENV["OPENAI_API_KEY"] = original_api_key
  end

  describe "POST /api/v1/meetings/:id/generate-minutes" do
    it "generates minutes from a pasted Discord log" do
      meeting = create(
        :meeting,
        source_type: "discord_log",
        raw_text: <<~TEXT
          alice: Decision: ship the backend slice before the frontend.
          bob: Open question: who owns CI?
          alice: Action: add request specs for minutes generation.
        TEXT
      )
      authorize_project(meeting.project)

      post "/api/v1/meetings/#{meeting.id}/generate-minutes", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      minute = Minute.find(Job.find(body.dig("data", "job_id")).target_id)
      expect(minute.decisions.first.fetch("text")).to include("backend slice")
      expect(minute.open_questions.first).to include("CI")
      expect(minute.action_items.first.fetch("text")).to include("request specs")
      expect(minute.generated_by_model).to eq("deterministic-minutes-placeholder-v1")
      expect(meeting.project.audit_logs.last.action).to eq("minutes.generated")
    end

    it "generates minutes through the OpenAI provider when configured" do
      ENV["MINUTES_GENERATION_PROVIDER"] = "openai"
      ENV["OPENAI_API_KEY"] = "test-openai-key"
      meeting = create(:meeting, source_type: "discord_log", raw_text: "Decision: use OpenAI structured output.")
      authorize_project(meeting.project)
      provider = instance_double(
        MinutesGeneration::OpenaiProvider,
        generate: {
          status: "generated",
          summary: "OpenAI generated summary.",
          decisions: [{ text: "Use OpenAI structured output." }],
          open_questions: [],
          action_items: [{ text: "Wire provider tests.", status: "open" }],
          generated_by_model: "gpt-test"
        }
      )
      allow(MinutesGeneration::OpenaiProvider).to receive(:new).and_return(provider)

      post "/api/v1/meetings/#{meeting.id}/generate-minutes", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("data", "job_id"))
      minute = Minute.find(job.target_id)
      expect(job.status).to eq("succeeded")
      expect(minute.summary).to eq("OpenAI generated summary.")
      expect(minute.generated_by_model).to eq("gpt-test")
    end

    it "stores a failed job when OpenAI is forced but not connected" do
      ENV["MINUTES_GENERATION_PROVIDER"] = "openai"
      ENV.delete("OPENAI_API_KEY")
      meeting = create(:meeting, source_type: "discord_log", raw_text: "Decision: connect real AI.")
      authorize_project(meeting.project)

      post "/api/v1/meetings/#{meeting.id}/generate-minutes", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:failed_dependency)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("error", "details", "job_id"))
      expect(job.status).to eq("failed")
      expect(job.error_code).to eq("integration_not_connected")
      expect(job.safe_error_detail).to eq("OpenAI API key is not configured.")
      expect(meeting.project.audit_logs.last.action).to eq("minutes.generation_failed")
    end

    it "stores a failed job with request metadata when the OpenAI provider fails" do
      ENV["MINUTES_GENERATION_PROVIDER"] = "openai"
      ENV["OPENAI_API_KEY"] = "test-openai-key"
      meeting = create(:meeting, source_type: "discord_log", raw_text: "Decision: keep AI failure audit-ready.")
      authorize_project(meeting.project)
      provider = instance_double(MinutesGeneration::OpenaiProvider)
      allow(provider).to receive(:generate).and_raise(
        MinutesGeneration::ProviderError.new(
          code: "rate_limit_exceeded",
          message: "OpenAI request failed with HTTP 429",
          safe_detail: "OpenAI request was rate limited. Retry after the provider limit resets.",
          http_status: :too_many_requests,
          request_id: "req_rate"
        )
      )
      allow(MinutesGeneration::OpenaiProvider).to receive(:new).and_return(provider)

      post "/api/v1/meetings/#{meeting.id}/generate-minutes", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:too_many_requests)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("error", "details", "job_id"))
      audit_log = meeting.project.audit_logs.last
      expect(job.status).to eq("failed")
      expect(job.error_code).to eq("rate_limit_exceeded")
      expect(job.safe_error_detail).to eq("OpenAI request was rate limited. Retry after the provider limit resets.")
      expect(body.dig("error", "details", "request_id")).to eq("req_rate")
      expect(audit_log.action).to eq("minutes.generation_failed")
      expect(audit_log.metadata).to include("request_id" => "req_rate", "provider_error_code" => "rate_limit_exceeded")
    end

    it "blocks sensitive content before OpenAI generation" do
      meeting = create(
        :meeting,
        source_type: "discord_log",
        raw_text: "alice: password=super-secret-value"
      )
      authorize_project(meeting.project)

      post "/api/v1/meetings/#{meeting.id}/generate-minutes", headers: auth_headers("dm-editor")

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("sensitive_content_blocked")
      expect(Job.last.status).to eq("failed")
    end

    it "rejects generation by read-only members" do
      meeting = create(:meeting)
      authorize_project(meeting.project, actor_id: "viewer-actor", role: "viewer")

      post "/api/v1/meetings/#{meeting.id}/generate-minutes", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "GET /api/v1/minutes/:id" do
    it "returns minutes" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "viewer-actor", role: "viewer")

      get "/api/v1/minutes/#{minute.id}", headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(minute.id)
    end
  end

  describe "PATCH /api/v1/minutes/:id" do
    it "updates minutes" do
      minute = create(:minute)
      authorize_project(minute.meeting.project)

      patch "/api/v1/minutes/#{minute.id}", params: {
        summary: "Updated summary",
        open_questions: ["What is the release date?"]
      }, headers: auth_headers("dm-editor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "summary")).to eq("Updated summary")
    end

    it "rejects updates from another project member" do
      minute = create(:minute)
      authorize_project(create(:project), actor_id: "other-admin", role: "admin")

      patch "/api/v1/minutes/#{minute.id}", params: { summary: "Leaked update" }, headers: auth_headers("other-admin")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "POST /api/v1/minutes/:id/approve" do
    it "approves minutes" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/minutes/#{minute.id}/approve", headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("approved")
    end

    it "rejects approval by editors" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "editor-actor", role: "editor")

      post "/api/v1/minutes/#{minute.id}/approve", headers: auth_headers("editor-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end
end
