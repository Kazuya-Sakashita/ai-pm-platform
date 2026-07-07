require "rails_helper"

RSpec.describe Operations::RetryRefailureRateQuery do
  include ActiveSupport::Testing::TimeHelpers

  describe "#call" do
    let!(:checked_at) { Time.zone.parse("2026-07-07 12:00:00") }
    let!(:project) { create(:project) }
    let!(:product_job) { create(:job, project: project, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt") }

    it "measures refailure rate from safe retry AuditLog and explicit queue mappings" do
      travel_to(checked_at) do
        record_retry_audit_log(project: project, product_job: product_job, solid_queue_job_id: 123, created_at: checked_at - 10.minutes)
        create(:job_queue_mapping, product_job: product_job, solid_queue_job_id: 123, active_job_id: "active-job-123")
        stub_failed_execution_rows(job_ids: [ 123 ], rows: [ [ 123, checked_at - 1.minute ] ])

        result = described_class.new(project: project).call(checked_at: checked_at)

        expect(result).to include(
          measured: true,
          retry_count: 1,
          denominator: 1,
          numerator: 1,
          rate: 1.0,
          threshold: 0.1
        )
        expect(result.fetch(:exclusions)).to include(
          missing_product_job_id: 0,
          missing_solid_queue_job_id: 0,
          mapping_mismatch: 0,
          solid_queue_unavailable: 0
        )
      end
    end

    it "excludes retry logs without matching queue mapping" do
      travel_to(checked_at) do
        record_retry_audit_log(project: project, product_job: product_job, solid_queue_job_id: 123, created_at: checked_at - 10.minutes)
        stub_failed_execution_rows(job_ids: [ 123 ], rows: [])

        result = described_class.new(project: project).call(checked_at: checked_at)

        expect(result).to include(
          measured: false,
          retry_count: 1,
          denominator: 0,
          numerator: 0,
          rate: nil
        )
        expect(result.fetch(:exclusions)).to include(mapping_mismatch: 1)
      end
    end

    it "counts refailed retry events without exceeding denominator" do
      travel_to(checked_at) do
        record_retry_audit_log(project: project, product_job: product_job, solid_queue_job_id: 123, created_at: checked_at - 10.minutes)
        create(:job_queue_mapping, product_job: product_job, solid_queue_job_id: 123, active_job_id: "active-job-123")
        stub_failed_execution_rows(job_ids: [ 123 ], rows: [ [ 123, checked_at - 5.minutes ], [ 123, checked_at - 1.minute ] ])

        result = described_class.new(project: project).call(checked_at: checked_at)

        expect(result).to include(
          measured: true,
          denominator: 1,
          numerator: 1,
          rate: 1.0
        )
      end
    end

    it "returns not measured when retry logs are absent" do
      result = described_class.new(project: project).call(checked_at: checked_at)

      expect(result).to include(
        measured: false,
        retry_count: 0,
        denominator: 0,
        numerator: 0,
        rate: nil,
        threshold: 0.1
      )
    end
  end

  def record_retry_audit_log(project:, product_job:, solid_queue_job_id:, created_at:)
    audit_log = AuditLog.record!(
      project: project,
      action: "operations.failed_job_retried",
      target: project,
      actor_id: "operator-1",
      summary: "失敗ジョブの再実行が要求されました。",
      metadata: {
        failed_job_id: 456,
        job_id: solid_queue_job_id,
        product_job_id: product_job.id,
        project_boundary_status: "verified",
        product_job_mapping_source: "explicit",
        reason_template: "operator_confirmed_safe_retry"
      }
    )
    audit_log.update!(created_at: created_at, updated_at: created_at)
  end

  def stub_failed_execution_rows(job_ids:, rows:)
    failed_execution_scope = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::FailedExecution).to receive(:where).with(job_id: job_ids).and_return(failed_execution_scope)
    allow(failed_execution_scope).to receive(:pluck).with(:job_id, :created_at).and_return(rows)
  end
end
