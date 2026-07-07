require "rails_helper"

RSpec.describe Operations::FailedJobReleaseGate do
  let!(:base_data) do
    {
      workers: [ { stale: false } ],
      queues: [ { oldest_unfinished_age_seconds: 299 } ],
      failed_executions: { count: 4 },
      failed_job_samples: [ { product_job_mapping_source: "explicit" } ],
      failed_job_operation_metrics: {
        retry_count: 9,
        discard_count: 4,
        rejected_count: 0,
        retry_refailure: {
          measured: true,
          rate: 0.0,
          numerator: 0,
          denominator: 9,
          threshold: 0.1
        }
      }
    }
  end

  describe "#call" do
    it "passes thresholds and still requires notification when operations exist" do
      result = described_class.new(data: base_data).call

      expect(result).to include(
        status: "pass",
        notification_required: true,
        notification_channel: "operations"
      )
      expect(result[:checks]).to include(
        hash_including(key: "failed_execution_count", status: "pass", observed_value: "4件"),
        hash_including(key: "retry_count", status: "pass", observed_value: "9件"),
        hash_including(key: "discard_count", status: "pass", observed_value: "4件"),
        hash_including(key: "boundary_rejected_count", status: "pass", observed_value: "0件"),
        hash_including(key: "retry_refailure_rate", status: "pass", observed_value: "0.0% (0/9)")
      )
    end

    it "warns at failed job, retry, discard, worker, queue, and mapping fallback thresholds" do
      data = base_data.merge(
        workers: [ { stale: true } ],
        queues: [ { oldest_unfinished_age_seconds: 300 }, { oldest_unfinished_age_seconds: 301 } ],
        failed_executions: { count: 5 },
        failed_job_samples: [ { product_job_mapping_source: "arguments" } ],
        failed_job_operation_metrics: {
          retry_count: 10,
          discard_count: 5,
          rejected_count: 0,
          retry_refailure: {
            measured: true,
            rate: 0.2,
            numerator: 2,
            denominator: 10,
            threshold: 0.1
          }
        }
      )

      result = described_class.new(data: data).call

      expect(result).to include(status: "warning", notification_required: true)
      expect(result[:checks]).to include(
        hash_including(key: "worker_heartbeat", status: "warning", observed_value: "古い応答1件"),
        hash_including(key: "oldest_unfinished_age", status: "warning", observed_value: "1 queue"),
        hash_including(key: "failed_execution_count", status: "warning", observed_value: "5件"),
        hash_including(key: "retry_count", status: "warning", observed_value: "10件"),
        hash_including(key: "discard_count", status: "warning", observed_value: "5件"),
        hash_including(key: "retry_refailure_rate", status: "warning", observed_value: "20.0% (2/10)"),
        hash_including(key: "mapping_fallback_sample_count", status: "warning", observed_value: "1件")
      )
    end

    it "blocks release when project boundary rejection exists" do
      data = base_data.merge(
        failed_job_operation_metrics: {
          retry_count: 0,
          discard_count: 0,
          rejected_count: 1
        }
      )

      result = described_class.new(data: data).call

      expect(result).to include(status: "blocked", notification_required: true)
      expect(result[:checks]).to include(
        hash_including(
          key: "boundary_rejected_count",
          status: "blocked",
          severity: "critical",
          observed_value: "1件"
        )
      )
    end

    it "keeps notification payload policy limited to safe metadata" do
      result = described_class.new(data: base_data).call

      expect(result.dig(:notification_policy, :payload_fields)).to include(
        "project_id",
        "failed_job_id",
        "queue_name",
        "reason_template",
        "operator_actor_id",
        "release_gate_status"
      )
      expect(result.dig(:notification_policy, :prohibited_fields)).to include(
        "raw_exception",
        "backtrace",
        "serialized_arguments",
        "token",
        "database_url",
        "dm_body",
        "ai_prompt"
      )
    end
  end

  describe ".unavailable" do
    it "blocks release when queue health cannot be evaluated" do
      result = described_class.unavailable

      expect(result).to include(status: "blocked", notification_required: true)
      expect(result[:checks]).to contain_exactly(
        hash_including(key: "queue_health_available", status: "blocked", severity: "critical")
      )
    end
  end
end
