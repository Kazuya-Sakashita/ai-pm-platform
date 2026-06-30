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

      post "/api/v1/minutes/#{minutes.id}/generate-requirement"

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

      post "/api/v1/minutes/#{minutes.id}/generate-requirement"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "status")).to eq("generated")
      expect(Job.where(target_type: "requirement")).to be_empty
    end
  end

  describe "GET /api/v1/requirements/:id" do
    it "returns a requirement" do
      requirement = create(:requirement)

      get "/api/v1/requirements/#{requirement.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "id")).to eq(requirement.id)
      expect(body.dig("data", "generated_by_model")).to eq("deterministic-requirements-placeholder-v1")
    end
  end

  describe "PATCH /api/v1/requirements/:id" do
    it "updates an editable requirement draft" do
      requirement = create(:requirement)

      patch "/api/v1/requirements/#{requirement.id}", params: {
        background: "Updated background",
        goal: "Updated goal",
        functional_requirements: ["FR-001: Updated functional requirement"],
        acceptance_criteria: ["Updated acceptance criterion"],
        open_questions: []
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "background")).to eq("Updated background")
      expect(body.dig("data", "functional_requirements")).to eq(["FR-001: Updated functional requirement"])
      expect(requirement.minute.meeting.project.audit_logs.last.action).to eq("requirement.updated")
    end
  end
end
