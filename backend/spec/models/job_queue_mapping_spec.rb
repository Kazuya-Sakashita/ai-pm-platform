require "rails_helper"

RSpec.describe JobQueueMapping, type: :model do
  describe ".record_solid_queue!" do
    it "records the explicit Solid Queue mapping for a Product Job" do
      product_job = create(:job, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt")
      active_job = instance_double(
        ActiveJob::Base,
        provider_job_id: "987",
        job_id: "active-job-987"
      )

      mapping = described_class.record_solid_queue!(
        product_job: product_job,
        active_job: active_job,
        queue_name: "github_reconciliation",
        job_class_name: "GithubIssuePublish::ReconciliationRetryJob",
        scheduled_at: 1.minute.from_now
      )

      expect(mapping).to have_attributes(
        project_id: product_job.project_id,
        job_id: product_job.id,
        provider: "solid_queue",
        solid_queue_job_id: 987,
        active_job_id: "active-job-987",
        queue_name: "github_reconciliation",
        job_class_name: "GithubIssuePublish::ReconciliationRetryJob"
      )
    end

    it "skips mapping when the queue adapter does not expose provider_job_id" do
      product_job = create(:job)
      active_job = instance_double(ActiveJob::Base, provider_job_id: nil, job_id: "active-job-987")

      expect(
        described_class.record_solid_queue!(
          product_job: product_job,
          active_job: active_job,
          queue_name: "github_reconciliation",
          job_class_name: "GithubIssuePublish::ReconciliationRetryJob",
          scheduled_at: 1.minute.from_now
        )
      ).to be_nil
    end

    it "rejects a mapping whose project does not match the Product Job" do
      product_job = create(:job)
      other_project = create(:project)

      mapping = build(:job_queue_mapping, product_job: product_job, project: other_project)

      expect(mapping).not_to be_valid
      expect(mapping.errors[:project_id]).to include("must match product job project")
    end
  end
end
