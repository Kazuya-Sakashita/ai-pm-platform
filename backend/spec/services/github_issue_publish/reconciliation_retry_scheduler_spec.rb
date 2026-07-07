require "rails_helper"
require "active_job/test_helper"

RSpec.describe GithubIssuePublish::ReconciliationRetryScheduler do
  include ActiveJob::TestHelper

  before do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "creates a queued audit job and schedules the retry job" do
    attempt = create(
      :github_issue_publish_attempt,
      status: "reconciliation_required",
      safe_error_code: "github_publish_reconciliation_no_match",
      reconciliation_retry_count: 1,
      next_reconciliation_retry_at: 1.minute.from_now
    )
    available_at = attempt.next_reconciliation_retry_at

    expect {
      described_class.call(attempt, available_at: available_at)
    }.to change(Job, :count).by(1)
      .and have_enqueued_job(GithubIssuePublish::ReconciliationRetryJob)

    job = Job.order(:created_at).last
    expect(job).to have_attributes(
      project_id: attempt.project_id,
      job_type: "github_reconciliation",
      status: "queued",
      target_type: "github_issue_publish_attempt",
      target_id: attempt.id,
      progress: 0
    )
    expect(enqueued_jobs.last[:queue]).to eq("github_reconciliation")
    expect(enqueued_jobs.last[:args]).to eq([attempt.id, job.id])
    expect(enqueued_jobs.last[:at]).to be_within(1.second).of(available_at.to_f)
    audit_log = attempt.project.audit_logs.find_by!(
      action: "issue_draft.github_publish_reconciliation_retry_scheduled"
    )
    expect(audit_log.metadata).to include(
      "attempt_id" => attempt.id,
      "job_id" => job.id,
      "reconciliation_retry_count" => 1,
      "safe_error_code" => "github_publish_reconciliation_no_match"
    )
  end

  it "records the explicit Solid Queue mapping when provider_job_id is available" do
    attempt = create(
      :github_issue_publish_attempt,
      status: "reconciliation_required",
      safe_error_code: "github_publish_reconciliation_no_match",
      reconciliation_retry_count: 1,
      next_reconciliation_retry_at: 1.minute.from_now
    )
    available_at = attempt.next_reconciliation_retry_at
    configured_job = double("ActiveJob::ConfiguredJob")
    enqueued_job = instance_double(
      ActiveJob::Base,
      provider_job_id: "987",
      job_id: "active-job-987"
    )
    allow(GithubIssuePublish::ReconciliationRetryJob).to receive(:set).with(wait_until: available_at).and_return(configured_job)
    allow(configured_job).to receive(:perform_later).and_return(enqueued_job)

    expect {
      described_class.call(attempt, available_at: available_at)
    }.to change(JobQueueMapping, :count).by(1)

    job = Job.order(:created_at).last
    expect(configured_job).to have_received(:perform_later).with(attempt.id, job.id)
    mapping = JobQueueMapping.last
    expect(mapping).to have_attributes(
      project_id: attempt.project_id,
      job_id: job.id,
      solid_queue_job_id: 987,
      active_job_id: "active-job-987",
      queue_name: "github_reconciliation",
      job_class_name: "GithubIssuePublish::ReconciliationRetryJob"
    )
    audit_log = attempt.project.audit_logs.find_by!(
      action: "issue_draft.github_publish_reconciliation_retry_scheduled"
    )
    expect(audit_log.metadata).to include(
      "job_id" => job.id,
      "solid_queue_job_id" => 987,
      "active_job_id" => "active-job-987",
      "product_job_mapping_source" => "explicit"
    )
  end

  it "does not enqueue retries for attempts that are no longer pending" do
    attempt = create(:github_issue_publish_attempt, status: "reconciled")

    expect {
      described_class.call(attempt, available_at: 1.minute.from_now)
    }.not_to change(Job, :count)
    expect(enqueued_jobs).to be_empty
  end
end
