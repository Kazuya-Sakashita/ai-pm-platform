require "rails_helper"
require "active_job/test_helper"

RSpec.describe GithubIssuePublish::ReconciliationRetryJob, type: :job do
  include ActiveJob::TestHelper

  it "uses the dedicated GitHub reconciliation queue" do
    expect(described_class.queue_name).to eq("github_reconciliation")
  end

  before do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  after do
    clear_enqueued_jobs
    clear_performed_jobs
  end

  it "runs reconciliation and marks the audit job succeeded" do
    attempt = create(
      :github_issue_publish_attempt,
      status: "reconciliation_required",
      next_reconciliation_retry_at: 1.minute.ago
    )
    job = create(
      :job,
      project: attempt.project,
      job_type: "github_reconciliation",
      status: "queued",
      target_type: "github_issue_publish_attempt",
      target_id: attempt.id
    )
    result = GithubIssuePublish::ReconciliationService::Result.new(
      status: "reconciled",
      matches: [{ github_issue_number: 42 }],
      review: nil,
      search_total_count: 1,
      search_incomplete_results: false,
      search_result_limit: 10,
      reconciliation_retry_count: attempt.reconciliation_retry_count,
      next_reconciliation_retry_at: nil
    )
    service = instance_double(GithubIssuePublish::ReconciliationService, call: result)
    allow(GithubIssuePublish::ReconciliationService).to receive(:new).with(attempt).and_return(service)

    described_class.perform_now(attempt.id, job.id)

    expect(job.reload.status).to eq("succeeded")
    expect(job.progress).to eq(100)
    audit_log = attempt.project.audit_logs.find_by!(
      action: "issue_draft.github_publish_reconciliation_retry_finished"
    )
    expect(audit_log.metadata).to include(
      "attempt_id" => attempt.id,
      "job_id" => job.id,
      "result_status" => "reconciled",
      "match_count" => 1
    )
  end

  it "reschedules when the attempt is still cooling down" do
    attempt = create(
      :github_issue_publish_attempt,
      status: "reconciliation_required",
      next_reconciliation_retry_at: 1.minute.from_now
    )
    job = create(
      :job,
      project: attempt.project,
      job_type: "github_reconciliation",
      status: "queued",
      target_type: "github_issue_publish_attempt",
      target_id: attempt.id
    )

    described_class.perform_now(attempt.id, job.id)

    expect(enqueued_jobs.last[:job]).to eq(described_class)
    expect(enqueued_jobs.last[:args]).to eq([attempt.id, job.id])
    expect(enqueued_jobs.last[:at]).to be_within(1.second).of(attempt.next_reconciliation_retry_at.to_f)
    expect(job.reload.status).to eq("queued")
    expect(attempt.project.audit_logs.find_by!(
      action: "issue_draft.github_publish_reconciliation_retry_rescheduled"
    ).metadata).to include("attempt_id" => attempt.id, "job_id" => job.id)
  end

  it "marks the audit job failed when reconciliation raises a safe provider error" do
    attempt = create(
      :github_issue_publish_attempt,
      status: "reconciliation_required",
      next_reconciliation_retry_at: 1.minute.ago
    )
    job = create(
      :job,
      project: attempt.project,
      job_type: "github_reconciliation",
      status: "queued",
      target_type: "github_issue_publish_attempt",
      target_id: attempt.id
    )
    error = GithubIssuePublish::ProviderError.new(
      code: "github_issue_marker_search_rate_limited",
      message: "GitHub search was rate limited.",
      safe_detail: "GitHub rate limit is active. Retry after the provider limit resets.",
      http_status: :too_many_requests,
      safe_metadata: { github_rate_limited: true }
    )
    service = instance_double(GithubIssuePublish::ReconciliationService)
    allow(service).to receive(:call).and_raise(error)
    allow(GithubIssuePublish::ReconciliationService).to receive(:new).with(attempt).and_return(service)

    expect {
      described_class.perform_now(attempt.id, job.id)
    }.to raise_error(GithubIssuePublish::ProviderError)

    expect(job.reload.status).to eq("failed")
    expect(job.progress).to eq(100)
    expect(job.error_code).to eq("github_issue_marker_search_rate_limited")
    expect(job.safe_error_detail).to eq("GitHub rate limit is active. Retry after the provider limit resets.")
    audit_log = attempt.project.audit_logs.find_by!(
      action: "issue_draft.github_publish_reconciliation_retry_failed"
    )
    expect(audit_log.metadata).to include(
      "attempt_id" => attempt.id,
      "job_id" => job.id,
      "provider_error_code" => "github_issue_marker_search_rate_limited",
      "github_rate_limited" => true
    )
  end

  it "cancels the audit job when the attempt is no longer pending" do
    attempt = create(:github_issue_publish_attempt, status: "reconciled")
    job = create(
      :job,
      project: attempt.project,
      job_type: "github_reconciliation",
      status: "queued",
      target_type: "github_issue_publish_attempt",
      target_id: attempt.id
    )

    described_class.perform_now(attempt.id, job.id)

    expect(job.reload.status).to eq("cancelled")
    expect(job.safe_error_detail).to eq("GitHub reconciliation attempt is no longer pending.")
    audit_log = attempt.project.audit_logs.find_by!(
      action: "issue_draft.github_publish_reconciliation_retry_cancelled"
    )
    expect(audit_log.metadata).to include(
      "attempt_id" => attempt.id,
      "job_id" => job.id,
      "attempt_status" => "reconciled"
    )
  end
end
