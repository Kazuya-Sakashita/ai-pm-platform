require "rails_helper"

RSpec.describe "API V1 Minutes", type: :request do
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

      post "/api/v1/meetings/#{meeting.id}/generate-minutes"

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      minute = Minute.find(Job.find(body.dig("data", "job_id")).target_id)
      expect(minute.decisions.first.fetch("text")).to include("backend slice")
      expect(minute.open_questions.first).to include("CI")
      expect(minute.action_items.first.fetch("text")).to include("request specs")
      expect(minute.generated_by_model).to eq("deterministic-minutes-placeholder-v1")
      expect(meeting.project.audit_logs.last.action).to eq("minutes.generated")
    end
  end

  describe "GET /api/v1/minutes/:id" do
    it "returns minutes" do
      minute = create(:minute)

      get "/api/v1/minutes/#{minute.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(minute.id)
    end
  end

  describe "PATCH /api/v1/minutes/:id" do
    it "updates minutes" do
      minute = create(:minute)

      patch "/api/v1/minutes/#{minute.id}", params: {
        summary: "Updated summary",
        open_questions: ["What is the release date?"]
      }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "summary")).to eq("Updated summary")
    end
  end

  describe "POST /api/v1/minutes/:id/approve" do
    it "approves minutes" do
      minute = create(:minute)

      post "/api/v1/minutes/#{minute.id}/approve"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("approved")
    end
  end
end
