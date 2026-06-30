require "rails_helper"

RSpec.describe "API V1 Issue Drafts", type: :request do
  describe "POST /api/v1/requirements/:id/generate-issue-draft" do
    it "generates an issue draft from an approved requirement" do
      requirement = create(
        :requirement,
        status: "approved",
        open_questions: [],
        goal: "Generate GitHub Issue drafts from approved requirements.",
        functional_requirements: ["FR-001: Generate issue drafts."],
        acceptance_criteria: ["Given an approved requirement, when generation runs, then an issue draft is stored."]
      )

      post "/api/v1/requirements/#{requirement.id}/generate-issue-draft"

      expect(response).to have_http_status(:accepted)
      body = JSON.parse(response.body)
      job = Job.find(body.dig("data", "job_id"))
      issue_draft = IssueDraft.find(job.target_id)
      expect(job.status).to eq("succeeded")
      expect(job.target_type).to eq("issue_draft")
      expect(issue_draft.title).to include("Generate GitHub Issue drafts")
      expect(issue_draft.body).to include("## Acceptance Criteria")
      expect(issue_draft.labels).to include("ai-generated", "requirement")
      expect(requirement.minute.meeting.project.audit_logs.last.action).to eq("issue_draft.generated")
    end

    it "requires an approved requirement before generation" do
      requirement = create(:requirement, status: "generated")

      post "/api/v1/requirements/#{requirement.id}/generate-issue-draft"

      expect(response).to have_http_status(:conflict)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("review_required")
      expect(body.dig("error", "details", "status")).to eq("generated")
      expect(Job.where(target_type: "issue_draft")).to be_empty
    end
  end

  describe "GET /api/v1/issue-drafts/:id" do
    it "returns an issue draft" do
      issue_draft = create(:issue_draft)

      get "/api/v1/issue-drafts/#{issue_draft.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(issue_draft.id)
    end
  end

  describe "PATCH /api/v1/issue-drafts/:id" do
    it "updates an editable issue draft" do
      issue_draft = create(:issue_draft)

      patch "/api/v1/issue-drafts/#{issue_draft.id}", params: {
        title: "Updated issue title",
        body: "Updated issue body",
        acceptance_criteria: ["Updated criterion"],
        labels: ["updated", "needs-review"]
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "title")).to eq("Updated issue title")
      expect(body.dig("data", "labels")).to eq(["updated", "needs-review"])
      expect(issue_draft.requirement.minute.meeting.project.audit_logs.last.action).to eq("issue_draft.updated")
    end
  end
end
