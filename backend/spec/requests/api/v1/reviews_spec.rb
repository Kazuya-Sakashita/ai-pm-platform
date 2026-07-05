require "rails_helper"

RSpec.describe "API V1 Reviews", type: :request do
  describe "POST /api/v1/reviews" do
    it "creates a review" do
      meeting = create(:meeting)
      authorize_project(meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/reviews", params: {
        target_type: "meeting",
        target_id: meeting.id,
        reviewer_role: "Tech Lead",
        framework: ["G-STACK"],
        positives: ["Traceable"],
        improvements: ["Add tests"],
        priority: ["P0"],
        next_actions: ["Write request spec"],
        issue_numbers: ["ISSUE-015"]
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("open")
    end

    it "stores a minutes review result" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")

      post "/api/v1/reviews", params: {
        target_type: "minutes",
        target_id: minute.id,
        reviewer_role: "QA",
        framework: ["ISO25010"],
        positives: ["Minutes are structured"],
        improvements: ["Clarify owners"],
        priority: ["P1"],
        next_actions: ["Assign action item owners"],
        issue_numbers: ["ISSUE-002"]
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).dig("data", "target_type")).to eq("minutes")
    end

    it "rejects reviews for project targets by non-members" do
      minute = create(:minute)

      post "/api/v1/reviews", params: {
        target_type: "minutes",
        target_id: minute.id,
        reviewer_role: "QA",
        framework: ["ISO25010"],
        positives: ["Structured"],
        improvements: ["Clarify owners"],
        priority: ["P1"],
        next_actions: ["Assign owners"],
        issue_numbers: ["ISSUE-002"]
      }, headers: auth_headers("outsider")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "POST /api/v1/reviews/:id/resolve-action" do
    it "marks a review as resolved" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "reviewer-actor", role: "reviewer")
      review = create(:review, target_type: "minutes", target_id: minute.id)

      post "/api/v1/reviews/#{review.id}/resolve-action", params: {
        resolution_note: "Request specs added."
      }, headers: auth_headers("reviewer-actor")

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("resolved")
    end

    it "rejects review resolution by editors" do
      minute = create(:minute)
      authorize_project(minute.meeting.project, actor_id: "editor-actor", role: "editor")
      review = create(:review, target_type: "minutes", target_id: minute.id)

      post "/api/v1/reviews/#{review.id}/resolve-action", params: {
        resolution_note: "Request specs added."
      }, headers: auth_headers("editor-actor")

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body).dig("error", "code")).to eq("project_forbidden")
    end
  end

  describe "GET /api/v1/reviews" do
    it "lists reviews only for the requested project" do
      visible_minute = create(:minute)
      hidden_minute = create(:minute)
      authorize_project(visible_minute.meeting.project, actor_id: "viewer-actor", role: "viewer")
      visible_review = create(:review, target_type: "minutes", target_id: visible_minute.id)
      create(:review, target_type: "minutes", target_id: hidden_minute.id)

      get "/api/v1/reviews", params: { project_id: visible_minute.meeting.project.id }, headers: auth_headers("viewer-actor")

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).fetch("data").map { |item| item.fetch("id") }
      expect(ids).to eq([visible_review.id])
    end
  end
end
