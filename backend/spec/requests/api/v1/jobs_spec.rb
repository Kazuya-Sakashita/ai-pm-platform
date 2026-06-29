require "rails_helper"

RSpec.describe "API V1 Jobs", type: :request do
  describe "GET /api/v1/jobs/:id" do
    it "returns a job" do
      job = create(:job)

      get "/api/v1/jobs/#{job.id}"

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "id")).to eq(job.id)
    end
  end
end
