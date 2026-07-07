module Operations
  class FailedJobReleaseGate
    HEARTBEAT_STALE_AFTER_SECONDS = QueueHealthQuery::HEARTBEAT_STALE_AFTER_SECONDS
    OLDEST_UNFINISHED_THRESHOLD_SECONDS = QueueHealthQuery::OLDEST_UNFINISHED_THRESHOLD_SECONDS
    FAILED_EXECUTION_WARNING_THRESHOLD = 5
    FAILED_JOB_RETRY_WARNING_THRESHOLD = 10
    FAILED_JOB_DISCARD_WARNING_THRESHOLD = 5
    FAILED_JOB_BOUNDARY_REJECTION_BLOCK_THRESHOLD = 1
    MAPPING_FALLBACK_WARNING_THRESHOLD = 1

    def self.pending
      new(data: nil).pending
    end

    def self.unavailable
      new(data: nil).unavailable
    end

    def initialize(data:)
      @data = data
    end

    def call
      checks = release_gate_checks
      status = release_gate_status(checks)

      {
        status: status,
        notification_required: status != "pass" || operation_count.positive?,
        notification_channel: "operations",
        notification_policy: notification_policy,
        approval_policy: approval_policy,
        checks: checks
      }
    end

    def pending
      {
        status: "not_evaluated",
        notification_required: false,
        notification_channel: "operations",
        notification_policy: notification_policy,
        approval_policy: approval_policy,
        checks: []
      }
    end

    def unavailable
      pending.merge(
        status: "blocked",
        notification_required: true,
        checks: [
          release_gate_check(
            key: "queue_health_available",
            label: "Queue health取得",
            status: "blocked",
            severity: "critical",
            observed_value: "取得不可",
            threshold: "取得可能",
            next_action: "queue database接続とSolid Queue schemaを確認し、release gateを停止します。"
          )
        ]
      )
    end

    private

    attr_reader :data

    def release_gate_checks
      [
        release_gate_check(
          key: "worker_heartbeat",
          label: "worker heartbeat",
          status: stale_worker_count.positive? ? "warning" : "pass",
          severity: "warning",
          observed_value: "古い応答#{stale_worker_count}件",
          threshold: "#{HEARTBEAT_STALE_AFTER_SECONDS}秒以内",
          next_action: "worker processとqueue database接続を確認します。"
        ),
        release_gate_check(
          key: "oldest_unfinished_age",
          label: "oldest unfinished age",
          status: old_unfinished_queue_count.positive? ? "warning" : "pass",
          severity: "warning",
          observed_value: "#{old_unfinished_queue_count} queue",
          threshold: "#{OLDEST_UNFINISHED_THRESHOLD_SECONDS}秒未満",
          next_action: "詰まっているqueueのworker数、外部API制限、例外ログを確認します。"
        ),
        release_gate_check(
          key: "failed_execution_count",
          label: "failed job残存件数",
          status: failed_execution_count >= FAILED_EXECUTION_WARNING_THRESHOLD ? "warning" : "pass",
          severity: "warning",
          observed_value: "#{failed_execution_count}件",
          threshold: "#{FAILED_EXECUTION_WARNING_THRESHOLD}件未満",
          next_action: "release ownerが残存理由と次回確認時刻を記録します。"
        ),
        release_gate_check(
          key: "retry_count",
          label: "24時間retry件数",
          status: retry_count >= FAILED_JOB_RETRY_WARNING_THRESHOLD ? "warning" : "pass",
          severity: "warning",
          observed_value: "#{retry_count}件",
          threshold: "#{FAILED_JOB_RETRY_WARNING_THRESHOLD}件未満",
          next_action: "retry理由と再失敗有無を確認し、必要なら再実行を停止します。"
        ),
        release_gate_check(
          key: "discard_count",
          label: "24時間discard件数",
          status: discard_count >= FAILED_JOB_DISCARD_WARNING_THRESHOLD ? "warning" : "pass",
          severity: "warning",
          observed_value: "#{discard_count}件",
          threshold: "#{FAILED_JOB_DISCARD_WARNING_THRESHOLD}件未満",
          next_action: "discard対象、承認者、復旧不要の根拠を確認します。"
        ),
        release_gate_check(
          key: "boundary_rejected_count",
          label: "Project境界拒否件数",
          status: rejected_count >= FAILED_JOB_BOUNDARY_REJECTION_BLOCK_THRESHOLD ? "blocked" : "pass",
          severity: "critical",
          observed_value: "#{rejected_count}件",
          threshold: "0件",
          next_action: "権限境界またはmapping異常としてreleaseを止め、Security Engineerが確認します。"
        ),
        release_gate_check(
          key: "mapping_fallback_sample_count",
          label: "明示mapping未使用sample数",
          status: mapping_fallback_count >= MAPPING_FALLBACK_WARNING_THRESHOLD ? "warning" : "pass",
          severity: "warning",
          observed_value: "#{mapping_fallback_count}件",
          threshold: "0件",
          next_action: "既存job由来かmapping保存失敗かを確認し、必要ならmapping保存経路を修正します。"
        ),
        release_gate_check(
          key: "retry_refailure_rate",
          label: "retry後再失敗率",
          status: "not_measured",
          severity: "info",
          observed_value: "未計測",
          threshold: "10%未満",
          next_action: "job_queue_mappingsとAuditLogのretry履歴から計測する後続Issueを作成します。"
        )
      ]
    end

    def release_gate_status(checks)
      return "blocked" if checks.any? { |check| check[:status] == "blocked" }
      return "warning" if checks.any? { |check| check[:status] == "warning" }

      "pass"
    end

    def release_gate_check(key:, label:, status:, severity:, observed_value:, threshold:, next_action:)
      {
        key: key,
        label: label,
        status: status,
        severity: severity,
        observed_value: observed_value,
        threshold: threshold,
        next_action: next_action
      }
    end

    def notification_policy
      {
        channel: "operations",
        required_for: [ "release_gate_warning", "release_gate_blocked", "failed_job_operation_executed", "notification_failed" ],
        payload_fields: [
          "project_id",
          "failed_job_id",
          "job_id",
          "queue_name",
          "class_name",
          "action",
          "reason_template",
          "operator_actor_id",
          "audit_log_action",
          "release_gate_status"
        ],
        prohibited_fields: [
          "raw_exception",
          "backtrace",
          "serialized_arguments",
          "token",
          "database_url",
          "dm_body",
          "ai_prompt"
        ],
        fallback: "通知失敗時はAuditLogまたはrelease evidenceへsafe metadataのみを保存し、release ownerが手動確認します。"
      }
    end

    def approval_policy
      {
        retry: approval_policy_rule(
          operation: "retry",
          approval_required: false,
          second_approval_required: false,
          required_role: "admin以上",
          next_action: "理由テンプレートと副作用確認をAuditLogに残します。"
        ),
        discard: approval_policy_rule(
          operation: "discard",
          approval_required: true,
          second_approval_required: true,
          required_role: "ownerまたはrelease owner",
          next_action: "本番discardは二人承認またはrelease owner承認を証跡化します。"
        ),
        production: approval_policy_rule(
          operation: "production_failed_job_operation",
          approval_required: true,
          second_approval_required: true,
          required_role: "incident commanderまたはrelease owner",
          next_action: "productionは観測のみを既定とし、実操作時は承認、Project特定、AuditLog確認を必須にします。"
        )
      }
    end

    def approval_policy_rule(operation:, approval_required:, second_approval_required:, required_role:, next_action:)
      {
        operation: operation,
        approval_required: approval_required,
        second_approval_required: second_approval_required,
        required_role: required_role,
        next_action: next_action
      }
    end

    def metrics
      data.fetch(:failed_job_operation_metrics)
    end

    def failed_execution_count
      data.dig(:failed_executions, :count).to_i
    end

    def retry_count
      metrics.fetch(:retry_count).to_i
    end

    def discard_count
      metrics.fetch(:discard_count).to_i
    end

    def rejected_count
      metrics.fetch(:rejected_count).to_i
    end

    def operation_count
      retry_count + discard_count + rejected_count
    end

    def stale_worker_count
      data.fetch(:workers).count { |worker| worker[:stale] }
    end

    def old_unfinished_queue_count
      data.fetch(:queues).count do |queue|
        queue.fetch(:oldest_unfinished_age_seconds, 0).to_i > OLDEST_UNFINISHED_THRESHOLD_SECONDS
      end
    end

    def mapping_fallback_count
      data.fetch(:failed_job_samples).count do |sample|
        sample[:product_job_mapping_source] != "explicit"
      end
    end
  end
end
