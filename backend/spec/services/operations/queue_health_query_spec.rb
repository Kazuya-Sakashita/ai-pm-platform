require "rails_helper"

RSpec.describe Operations::QueueHealthQuery do
  include ActiveSupport::Testing::TimeHelpers

  describe "#call" do
    it "returns safe queue health summary when Solid Queue tables are available" do
      checked_at = Time.zone.parse("2026-07-04 12:00:00")
      project = create(:project)
      product_job = create(:job, project: project, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt", status: "failed", safe_error_detail: "raw provider failure")

      travel_to(checked_at) do
        stub_solid_queue_tables(available: true)
        stub_worker(last_heartbeat_at: checked_at - 10.seconds)
        stub_unfinished_jobs(queue_name: "github_reconciliation", count: 2, oldest_at: checked_at - 400.seconds)
        stub_failed_job_samples(failed_at: checked_at - 30.seconds, product_job: product_job)
        stub_recurring_tasks
        record_failed_job_operation_logs(project: project, product_job: product_job, checked_at: checked_at)

        data = described_class.new(project: project).call

        expect(data[:status]).to eq("degraded")
        expect(data[:workers]).to contain_exactly(hash_including(kind: "worker", name: "worker-1", stale: false))
        expect(data[:queues]).to include(hash_including(queue_name: "github_reconciliation", unfinished_count: 2, oldest_unfinished_age_seconds: 400))
        expect(data[:failed_executions]).to include(count: 1, latest_failed_at: (checked_at - 30.seconds).iso8601)
        expect(data[:failed_job_samples]).to contain_exactly(
          {
            failed_job_id: 456,
            job_id: 123,
            product_job_id: product_job.id,
            project_id: project.id,
            project_boundary_status: "verified",
            queue_name: "github_reconciliation",
            class_name: "GithubIssuePublish::ReconciliationRetryJob",
            active_job_id: "active-job-123",
            failed_at: (checked_at - 30.seconds).iso8601,
            operations: {
              retryable: true,
              discardable: true,
              retry_reason_templates: Operations::FailedJobOperationService::RETRY_REASON_TEMPLATES.keys,
              discard_reason_templates: Operations::FailedJobOperationService::DISCARD_REASON_TEMPLATES.keys,
              reason_templates: Operations::FailedJobOperationService::REASON_TEMPLATES.keys
            }
          }
        )
        expect(data[:failed_job_operation_metrics]).to include(
          recent_window_hours: 24,
          retry_count: 1,
          discard_count: 1,
          rejected_count: 1,
          last_operated_at: checked_at.iso8601
        )
        expect(data[:failed_job_operation_history]).to contain_exactly(
          hash_including(action: "retry", outcome: "succeeded", reason_template: "operator_confirmed_safe_retry", product_job_id: product_job.id),
          hash_including(action: "discard", outcome: "succeeded", reason_template: "manually_resolved", discard_safety_confirmed: true),
          hash_including(action: "boundary_rejected", outcome: "rejected", project_boundary_status: "project_mismatch")
        )
        expect(data[:recurring_tasks]).to contain_exactly(hash_including(key: "cleanup_expired_github_connection_states"))
        expect(data.dig(:product_jobs, :recent_failed_count)).to eq(1)
        expect(data.to_s).not_to include("raw provider failure")
        expect(data.to_s).not_to include("raw solid queue error")
        expect(data.to_s).not_to include("backtrace")
        expect(data.to_s).not_to include("DATABASE_URL")
      end
    end

    it "returns unavailable fallback when Solid Queue tables are unavailable" do
      create(:job, status: "failed", safe_error_detail: "raw provider failure")

      stub_solid_queue_tables(available: false)

      data = described_class.new.call

      expect(data[:status]).to eq("unavailable")
      expect(data[:warnings].join(" ")).to include("Solid Queue")
      expect(data[:failed_executions]).to eq(count: 0)
      expect(data[:failed_job_samples]).to eq([])
      expect(data[:failed_job_operation_metrics]).to include(retry_count: 0, discard_count: 0, rejected_count: 0)
      expect(data[:failed_job_operation_history]).to eq([])
      expect(data.dig(:product_jobs, :recent_failed_count)).to eq(1)
      expect(data.to_s).not_to include("raw provider failure")
    end

    it "hides failed job samples that do not belong to the requested project" do
      checked_at = Time.zone.parse("2026-07-04 12:00:00")
      project = create(:project)
      other_project = create(:project)
      other_product_job = create(:job, project: other_project, job_type: "github_reconciliation", target_type: "github_issue_publish_attempt")

      travel_to(checked_at) do
        stub_solid_queue_tables(available: true)
        stub_worker(last_heartbeat_at: checked_at - 10.seconds)
        stub_unfinished_jobs(queue_name: "github_reconciliation", count: 0, oldest_at: nil)
        stub_failed_job_samples(failed_at: checked_at - 30.seconds, product_job: other_product_job)
        stub_recurring_tasks

        data = described_class.new(project: project).call

        expect(data[:failed_executions]).to eq(count: 0)
        expect(data[:failed_job_samples]).to eq([])
        expect(data.to_s).not_to include(other_product_job.id)
      end
    end
  end

  def stub_solid_queue_tables(available:)
    connection = instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter)
    allow(connection).to receive(:data_source_exists?).and_return(available)

    [
      SolidQueue::Job,
      SolidQueue::Process,
      SolidQueue::FailedExecution,
      SolidQueue::RecurringTask
    ].each do |model|
      allow(model).to receive(:connection).and_return(connection)
    end
  end

  def stub_worker(last_heartbeat_at:)
    worker = double(
      "SolidQueue::Process",
      kind: "worker",
      name: "worker-1",
      hostname: "worker-host",
      last_heartbeat_at: last_heartbeat_at
    )
    ordered_workers = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::Process).to receive(:order).with(last_heartbeat_at: :desc).and_return(ordered_workers)
    allow(ordered_workers).to receive(:limit).with(Operations::QueueHealthQuery::WORKER_LIMIT).and_return([ worker ])
  end

  def stub_unfinished_jobs(queue_name:, count:, oldest_at:)
    unfinished_scope = instance_double(ActiveRecord::Relation)
    grouped_scope = instance_double(ActiveRecord::Relation)

    allow(SolidQueue::Job).to receive(:where).with(finished_at: nil).and_return(unfinished_scope)
    allow(unfinished_scope).to receive(:group).with(:queue_name).and_return(grouped_scope)
    allow(grouped_scope).to receive(:count).and_return(queue_name => count)
    allow(grouped_scope).to receive(:minimum).with(:created_at).and_return(queue_name => oldest_at)
  end

  def stub_failed_job_samples(failed_at:, product_job:)
    failed_execution = double(
      "SolidQueue::FailedExecution",
      id: 456,
      job_id: 123,
      created_at: failed_at
    )
    expect(failed_execution).not_to receive(:error)

    ordered_failed_executions = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::FailedExecution).to receive(:order).with(created_at: :desc).and_return(ordered_failed_executions)
    allow(ordered_failed_executions).to receive(:limit).with(Operations::QueueHealthQuery::FAILED_JOB_LOOKUP_LIMIT).and_return([ failed_execution ])

    queue_job = double(
      "SolidQueue::Job",
      id: 123,
      queue_name: "github_reconciliation",
      class_name: "GithubIssuePublish::ReconciliationRetryJob",
      active_job_id: "active-job-123",
      arguments: {
        "job_class" => "GithubIssuePublish::ReconciliationRetryJob",
        "arguments" => [ SecureRandom.uuid, product_job.id ]
      }
    )
    jobs_relation = instance_double(ActiveRecord::Relation)
    allow(SolidQueue::Job).to receive(:where).with(id: [ 123 ]).and_return(jobs_relation)
    allow(jobs_relation).to receive(:index_by).and_return(123 => queue_job)
  end

  def stub_recurring_tasks
    task = double(
      "SolidQueue::RecurringTask",
      key: "cleanup_expired_github_connection_states",
      class_name: "GithubIntegration::ConnectionStateCleanupJob",
      queue_name: "default",
      schedule: "every hour at minute 24"
    )
    ordered_tasks = instance_double(ActiveRecord::Relation)

    allow(SolidQueue::RecurringTask).to receive(:order).with(:key).and_return(ordered_tasks)
    allow(ordered_tasks).to receive(:limit).with(Operations::QueueHealthQuery::RECURRING_TASK_LIMIT).and_return([ task ])
  end

  def record_failed_job_operation_logs(project:, product_job:, checked_at:)
    [
      [
        "operations.failed_job_retried",
        "失敗ジョブの再実行が要求されました。",
        {
          failed_job_id: 456,
          job_id: 123,
          product_job_id: product_job.id,
          project_boundary_status: "verified",
          reason_template: "operator_confirmed_safe_retry",
          reason_template_label: "運用者が副作用リスクを確認したため再実行します。"
        }
      ],
      [
        "operations.failed_job_discarded",
        "失敗ジョブの破棄が要求されました。",
        {
          failed_job_id: 457,
          job_id: 124,
          product_job_id: product_job.id,
          project_boundary_status: "verified",
          reason_template: "manually_resolved",
          reason_template_label: "手動対応済みのため破棄します。",
          discard_safety_confirmed: true
        }
      ],
      [
        "operations.failed_job_project_boundary_rejected",
        "失敗ジョブ操作のProject境界検証に失敗しました。",
        {
          failed_job_id: "458",
          project_boundary_status: "project_mismatch",
          requested_project_id: project.id,
          solid_queue_job_id: 125
        }
      ]
    ].each_with_index do |(action, summary, metadata), index|
      audit_log = AuditLog.record!(
        project: project,
        action: action,
        target: project,
        actor_id: "operator-#{index + 1}",
        summary: summary,
        metadata: metadata
      )
      audit_log.update!(created_at: checked_at - index.seconds, updated_at: checked_at - index.seconds)
    end
  end
end
