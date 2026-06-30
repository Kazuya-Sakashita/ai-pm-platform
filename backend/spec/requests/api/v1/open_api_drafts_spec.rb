require "rails_helper"

RSpec.describe "API V1 OpenAPI Drafts", type: :request do
  describe "POST /api/v1/requirements/:id/generate-openapi-draft" do
    it "generates an OpenAPI draft from an approved requirement" do
      requirement = create(
        :requirement,
        status: "approved",
        open_questions: [],
        goal: "Expose reviewed requirements as implementation-ready API contracts.",
        functional_requirements: ["FR-001: Generate OpenAPI draft after requirement approval."]
      )

      post "/api/v1/requirements/#{requirement.id}/generate-openapi-draft"

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("data", "job_id"))
      open_api_draft = OpenApiDraft.find(job.target_id)
      expect(job.status).to eq("succeeded")
      expect(job.target_type).to eq("openapi_draft")
      expect(open_api_draft.status).to eq("draft")
      expect(open_api_draft.requirement_id).to eq(requirement.id)
      expect(open_api_draft.content).to include("openapi: 3.1.0")
      expect(open_api_draft.validation_errors).to eq([])
      expect(requirement.minute.meeting.project.audit_logs.last.action).to eq("openapi_draft.generated")
    end

    it "requires approved requirements before OpenAPI draft generation" do
      requirement = create(:requirement, status: "generated")

      post "/api/v1/requirements/#{requirement.id}/generate-openapi-draft"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "status")).to eq("generated")
      expect(Job.where(target_type: "openapi_draft")).to be_empty
    end
  end

  describe "GET /api/v1/openapi-drafts/:id" do
    it "returns an OpenAPI draft" do
      open_api_draft = create(:open_api_draft)

      get "/api/v1/openapi-drafts/#{open_api_draft.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "id")).to eq(open_api_draft.id)
      expect(body.dig("data", "requirement_id")).to eq(open_api_draft.requirement_id)
      expect(body.dig("data", "validation_errors")).to eq([])
    end
  end

  describe "PATCH /api/v1/openapi-drafts/:id" do
    it "updates an editable OpenAPI draft" do
      open_api_draft = create(:open_api_draft)

      patch "/api/v1/openapi-drafts/#{open_api_draft.id}", params: {
        title: "Updated OpenAPI draft",
        content: "openapi: 3.1.0\ninfo:\n  title: Updated\n  version: 0.1.0\npaths: {}\n",
        status: "valid"
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "title")).to eq("Updated OpenAPI draft")
      expect(body.dig("data", "status")).to eq("valid")
      expect(open_api_draft.requirement.minute.meeting.project.audit_logs.last.action).to eq("openapi_draft.updated")
    end
  end
end
