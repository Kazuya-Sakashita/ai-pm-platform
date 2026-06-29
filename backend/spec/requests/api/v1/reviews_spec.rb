require "rails_helper"

RSpec.describe "API V1 Reviews", type: :request do
  describe "POST /api/v1/reviews" do
    it "creates a review" do
      post "/api/v1/reviews", params: {
        target_type: "meeting",
        target_id: SecureRandom.uuid,
        reviewer_role: "Tech Lead",
        framework: ["G-STACK"],
        positives: ["Traceable"],
        improvements: ["Add tests"],
        priority: ["P0"],
        next_actions: ["Write request spec"],
        issue_numbers: ["ISSUE-015"]
      }

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("open")
    end
  end

  describe "POST /api/v1/reviews/:id/resolve-action" do
    it "marks a review as resolved" do
      review = create(:review)

      post "/api/v1/reviews/#{review.id}/resolve-action", params: {
        resolution_note: "Request specs added."
      }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "status")).to eq("resolved")
    end
  end
end
