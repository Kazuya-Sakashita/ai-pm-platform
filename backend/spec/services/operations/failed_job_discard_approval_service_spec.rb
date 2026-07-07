require "rails_helper"

RSpec.describe Operations::FailedJobDiscardApprovalService do
  describe "#request" do
    let!(:project) { create(:project) }
    let!(:product_job) { create(:job, project: project, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt") }
    let!(:requester_membership) { create(:project_membership, project: project, actor_id: "operator-1", role: "admin") }
    let!(:failed_execution) { failed_execution_double(product_job: product_job) }

    before do
      stub_failed_execution_lookup(failed_execution)
    end

    it "creates a pending discard approval with safe audit metadata" do
      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        failed_job_id: "456",
        reason_template: "manually_resolved",
        discard_safety_confirmed: true
      ).request

      expect(result).to be_success
      approval = project.failed_job_discard_approvals.find(result.data.fetch(:id))
      expect(approval.status).to eq("pending")
      expect(approval.requested_by_actor_id).to eq("operator-1")
      expect(approval.requested_by_role).to eq("admin")
      expect(approval.product_job_id).to eq(product_job.id)

      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_discard_approval_requested")
      expect(audit_log.metadata).to include(
        "id" => approval.id,
        "failed_job_id" => 456,
        "job_id" => 123,
        "product_job_id" => product_job.id,
        "requested_by_actor_id" => "operator-1",
        "reason_template" => "manually_resolved"
      )
      expect(audit_log.metadata.to_s).not_to include("raw exception")
      expect(audit_log.metadata.to_s).not_to include("backtrace")
      expect(audit_log.metadata.to_s).not_to include("serialized_arguments")
    end
  end

  describe "#approve" do
    let!(:project) { create(:project) }
    let!(:owner_membership) { create(:project_membership, project: project, actor_id: "owner-1", role: "owner") }
    let!(:approval) { create(:failed_job_discard_approval, project: project, requested_by_actor_id: "operator-1") }

    it "approves a pending approval by a different actor without storing the note body in audit metadata" do
      result = described_class.new(
        project: project,
        actor_id: "owner-1",
        approval_id: approval.id,
        approval_note: "対象と復旧不要の根拠を確認しました。"
      ).approve

      expect(result).to be_success
      expect(approval.reload.status).to eq("approved")
      expect(approval.approved_by_actor_id).to eq("owner-1")
      expect(approval.approved_by_role).to eq("owner")

      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_discard_approval_approved")
      expect(audit_log.metadata).to include("id" => approval.id, "approval_note_present" => true)
      expect(audit_log.metadata.to_s).not_to include("対象と復旧不要の根拠")
    end

    it "rejects approval by the requester actor" do
      result = described_class.new(
        project: project,
        actor_id: "operator-1",
        approval_id: approval.id,
        approval_note: "自分で承認します。"
      ).approve

      expect(result).not_to be_success
      expect(result.code).to eq("failed_job_discard_approval_same_actor")
      expect(approval.reload.status).to eq("pending")
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
      job: queue_job
    )
  end

  def solid_queue_arguments(product_job)
    {
      "job_class" => "GithubIssuePublish::ReconciliationRetryJob",
      "arguments" => [ SecureRandom.uuid, product_job.id ]
    }
  end

  def stub_failed_execution_lookup(failed_execution)
    relation = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::FailedExecution).to receive(:includes).with(:job).and_return(relation)
    allow(relation).to receive(:find_by).with(id: "456").and_return(failed_execution)
  end
end
