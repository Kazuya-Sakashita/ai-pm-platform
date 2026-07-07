require "rails_helper"

RSpec.describe Operations::FailedJobOperationService do
  describe "#call" do
    it "retries a failed job and stores a safe audit log" do
      project = create(:project)
      failed_execution = failed_execution_double

      stub_failed_execution_lookup(failed_execution)

      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "retry",
        reason_template: "operator_confirmed_safe_retry"
      ).call

      expect(result).to be_success
      expect(failed_execution).to have_received(:retry)
      expect(result.data).to include(
        failed_job_id: 456,
        job_id: 123,
        action: "retry",
        queue_name: "github_reconciliation",
        class_name: "GithubIssuePublish::ReconciliationRetryJob",
        reason_template: "operator_confirmed_safe_retry"
      )

      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_retried")
      expect(audit_log.actor_id).to eq("operator-1")
      expect(audit_log.summary).to eq("失敗ジョブの再実行が要求されました。")
      expect(audit_log.metadata).to include(
        "failed_job_id" => 456,
        "job_id" => 123,
        "operator_actor_id" => "operator-1",
        "reason_template" => "operator_confirmed_safe_retry"
      )
      expect(audit_log.metadata.to_s).not_to include("raw exception")
      expect(audit_log.metadata.to_s).not_to include("backtrace")
      expect(audit_log.metadata.to_s).not_to include("DATABASE_URL")
    end

    it "discards a failed job and stores a safe audit log" do
      project = create(:project)
      failed_execution = failed_execution_double

      stub_failed_execution_lookup(failed_execution)

      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "discard",
        reason_template: "manually_resolved"
      ).call

      expect(result).to be_success
      expect(failed_execution).to have_received(:discard)
      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_discarded")
      expect(audit_log.summary).to eq("失敗ジョブの破棄が要求されました。")
      expect(audit_log.metadata).to include(
        "failed_job_id" => 456,
        "job_id" => 123,
        "reason_template" => "manually_resolved"
      )
    end

    it "rejects an unknown reason template" do
      result = described_class.new(
        project: create(:project),
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "retry",
        reason_template: "free_form_reason"
      ).call

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_reason_template_invalid")
      expect(result.http_status).to eq(:unprocessable_entity)
    end

    it "returns not_found when the failed job no longer exists" do
      relation = instance_double(ActiveRecord::Relation)
      allow(SolidQueue::FailedExecution).to receive(:includes).with(:job).and_return(relation)
      allow(relation).to receive(:find_by).with(id: "456").and_return(nil)

      result = described_class.new(
        project: create(:project),
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "retry",
        reason_template: "transient_failure_recovered"
      ).call

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_not_found")
      expect(result.http_status).to eq(:not_found)
    end
  end

  def failed_execution_double
    queue_job = double(
      "SolidQueue::Job",
      queue_name: "github_reconciliation",
      class_name: "GithubIssuePublish::ReconciliationRetryJob",
      active_job_id: "active-job-123"
    )

    double(
      "SolidQueue::FailedExecution",
      id: 456,
      job_id: 123,
      job: queue_job,
      retry: true,
      discard: true
    )
  end

  def stub_failed_execution_lookup(failed_execution)
    relation = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::FailedExecution).to receive(:includes).with(:job).and_return(relation)
    allow(relation).to receive(:find_by).with(id: "456").and_return(failed_execution)
  end
end
