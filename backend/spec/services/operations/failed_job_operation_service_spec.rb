require "rails_helper"

RSpec.describe Operations::FailedJobOperationService do
  describe "#call" do
    it "retries a failed job and stores a safe audit log" do
      project = create(:project)
      product_job = create(:job, project: project, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt")
      failed_execution = failed_execution_double(product_job: product_job)

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
        product_job_id: product_job.id,
        project_id: project.id,
        project_boundary_status: "verified",
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
        "product_job_id" => product_job.id,
        "project_id" => project.id,
        "project_boundary_status" => "verified",
        "operator_actor_id" => "operator-1",
        "reason_template" => "operator_confirmed_safe_retry"
      )
      expect(audit_log.metadata.to_s).not_to include("raw exception")
      expect(audit_log.metadata.to_s).not_to include("backtrace")
      expect(audit_log.metadata.to_s).not_to include("DATABASE_URL")
    end

    it "discards a failed job and stores a safe audit log" do
      project = create(:project)
      product_job = create(:job, project: project, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt")
      failed_execution = failed_execution_double(product_job: product_job)

      stub_failed_execution_lookup(failed_execution)

      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "discard",
        reason_template: "manually_resolved",
        discard_safety_confirmed: true
      ).call

      expect(result).to be_success
      expect(failed_execution).to have_received(:discard)
      expect(result.data).to include(discard_safety_confirmed: true)
      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_discarded")
      expect(audit_log.summary).to eq("失敗ジョブの破棄が要求されました。")
      expect(audit_log.metadata).to include(
        "failed_job_id" => 456,
        "job_id" => 123,
        "product_job_id" => product_job.id,
        "project_boundary_status" => "verified",
        "reason_template" => "manually_resolved",
        "discard_safety_confirmed" => true
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
      expect(result.details).to include(allowed_reason_templates: Operations::FailedJobOperationService::RETRY_REASON_TEMPLATES.keys)
    end

    it "rejects a discard-only reason template for retry" do
      result = described_class.new(
        project: create(:project),
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "retry",
        reason_template: "manually_resolved"
      ).call

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_reason_template_invalid")
      expect(result.details).to include(
        action: "retry",
        allowed_reason_templates: Operations::FailedJobOperationService::RETRY_REASON_TEMPLATES.keys
      )
    end

    it "requires explicit confirmation before discard" do
      project = create(:project)

      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "discard",
        reason_template: "manually_resolved"
      ).call

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_discard_confirmation_required")
      expect(result.http_status).to eq(:unprocessable_entity)
      expect(result.details).to include(action: "discard", discard_safety_confirmed: false)
      expect(project.audit_logs).to be_empty
    end

    it "rejects a retry-only reason template for discard" do
      result = described_class.new(
        project: create(:project),
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "discard",
        reason_template: "operator_confirmed_safe_retry",
        discard_safety_confirmed: true
      ).call

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_reason_template_invalid")
      expect(result.details).to include(
        action: "discard",
        allowed_reason_templates: Operations::FailedJobOperationService::DISCARD_REASON_TEMPLATES.keys
      )
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

    it "rejects a failed job associated with another project and records safe boundary metadata" do
      project = create(:project)
      other_project = create(:project)
      other_product_job = create(:job, project: other_project, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt")
      failed_execution = failed_execution_double(product_job: other_product_job)

      stub_failed_execution_lookup(failed_execution)

      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "retry",
        reason_template: "operator_confirmed_safe_retry"
      ).call

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_not_found")
      expect(result.http_status).to eq(:not_found)
      expect(failed_execution).not_to have_received(:retry)

      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_project_boundary_rejected")
      expect(audit_log.metadata).to include(
        "failed_job_id" => "456",
        "project_boundary_status" => "project_mismatch",
        "requested_project_id" => project.id,
        "solid_queue_job_id" => 123,
        "operator_actor_id" => "operator-1"
      )
      expect(audit_log.metadata).not_to include("product_job_id")
      expect(audit_log.metadata).not_to include("product_job_project_id")
      expect(audit_log.metadata.to_s).not_to include("raw exception")
      expect(audit_log.metadata.to_s).not_to include("backtrace")
      expect(audit_log.metadata.to_s).not_to include(other_project.id)
    end

    it "rejects a failed job when the product job cannot be resolved" do
      project = create(:project)
      failed_execution = failed_execution_double(product_job: nil)

      stub_failed_execution_lookup(failed_execution)

      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        failed_job_id: "456",
        action: "discard",
        reason_template: "manually_resolved",
        discard_safety_confirmed: true
      ).call

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_not_found")
      expect(failed_execution).not_to have_received(:discard)

      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_project_boundary_rejected")
      expect(audit_log.metadata).to include(
        "failed_job_id" => "456",
        "project_boundary_status" => "product_job_unresolved",
        "requested_project_id" => project.id,
        "solid_queue_job_id" => 123,
        "operator_actor_id" => "operator-1"
      )
    end
  end

  def failed_execution_double(product_job:)
    queue_job = double(
      "SolidQueue::Job",
      id: 123,
      queue_name: "github_reconciliation",
      class_name: "GithubIssuePublish::ReconciliationRetryJob",
      active_job_id: "active-job-123",
      arguments: solid_queue_arguments(product_job)
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

  def solid_queue_arguments(product_job)
    {
      "job_class" => "GithubIssuePublish::ReconciliationRetryJob",
      "arguments" => [ SecureRandom.uuid, product_job&.id || SecureRandom.uuid ]
    }
  end

  def stub_failed_execution_lookup(failed_execution)
    relation = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::FailedExecution).to receive(:includes).with(:job).and_return(relation)
    allow(relation).to receive(:find_by).with(id: "456").and_return(failed_execution)
  end
end
