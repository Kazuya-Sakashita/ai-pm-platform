require "rails_helper"

RSpec.describe Operations::FailedJobProjectResolver do
  describe "#call" do
    it "verifies a Solid Queue job that contains one Product Job id" do
      project = create(:project)
      product_job = create(:job, project: project)
      solid_queue_job = solid_queue_job_double(product_job.id)

      result = described_class.new(solid_queue_job).call

      expect(result.status).to eq("verified")
      expect(result).to be_verified_for(project)
      expect(result.safe_metadata(project: project)).to include(
        project_boundary_status: "verified",
        product_job_id: product_job.id,
        product_job_project_id: project.id,
        solid_queue_job_id: 123
      )
    end

    it "marks another Project job as mismatch without exposing other Project ids" do
      project = create(:project)
      other_project = create(:project)
      other_product_job = create(:job, project: other_project)
      solid_queue_job = solid_queue_job_double(other_product_job.id)

      result = described_class.new(solid_queue_job).call

      expect(result.status).to eq("verified")
      expect(result).not_to be_verified_for(project)
      expect(result.safe_metadata(project: project)).to include(
        project_boundary_status: "project_mismatch",
        requested_project_id: project.id,
        solid_queue_job_id: 123
      )
      expect(result.safe_metadata(project: project)).not_to include(:product_job_id)
      expect(result.safe_metadata(project: project)).not_to include(:product_job_project_id)
    end

    it "rejects ambiguous Product Job ids" do
      first_job = create(:job)
      second_job = create(:job)
      solid_queue_job = solid_queue_job_double(first_job.id, second_job.id)

      result = described_class.new(solid_queue_job).call

      expect(result.status).to eq("product_job_ambiguous")
      expect(result).not_to be_verified_for(first_job.project)
    end

    it "rejects unresolved Product Job ids" do
      solid_queue_job = solid_queue_job_double(SecureRandom.uuid)

      result = described_class.new(solid_queue_job).call

      expect(result.status).to eq("product_job_unresolved")
    end
  end

  def solid_queue_job_double(*ids)
    double(
      "SolidQueue::Job",
      id: 123,
      active_job_id: "active-job-123",
      arguments: {
        "job_class" => "GithubIssuePublish::ReconciliationRetryJob",
        "arguments" => [ SecureRandom.uuid, *ids ]
      }
    )
  end
end
