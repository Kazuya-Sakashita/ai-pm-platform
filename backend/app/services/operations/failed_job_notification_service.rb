require "digest"

module Operations
  class FailedJobNotificationService
    RELEASE_GATE_COOLDOWN = 1.hour
    DELIVERY_AUDIT_ACTIONS = [
      "operations.failed_job_notification_sent",
      "operations.failed_job_notification_failed"
    ].freeze
    SAFE_PAYLOAD_KEYS = [
      :project_id,
      :failed_job_id,
      :job_id,
      :queue_name,
      :class_name,
      :action,
      :reason_template,
      :operator_actor_id,
      :audit_log_action,
      :release_gate_status,
      :checks
    ].freeze
    SAFE_CHECK_KEYS = [
      :key,
      :label,
      :status,
      :severity,
      :observed_value,
      :threshold,
      :next_action
    ].freeze

    Result = Struct.new(:success?, :status, :code, :message, :details, keyword_init: true)

    def initialize(gateway: NotificationGateway.new, clock: -> { Time.current }, release_gate_cooldown: RELEASE_GATE_COOLDOWN)
      @gateway = gateway
      @clock = clock
      @release_gate_cooldown = release_gate_cooldown
    end

    def notify_release_gate(project:, release_gate:, actor_id: "system")
      status = release_gate_value(release_gate, :status).to_s
      return skipped_result("release_gate_notification_not_required") if %w[pass not_evaluated].include?(status)

      event = status == "blocked" ? "release_gate_blocked" : "release_gate_warning"
      payload = safe_payload(
        project_id: project.id,
        release_gate_status: status,
        checks: notification_checks(release_gate)
      )
      dedupe_key = notification_dedupe_key(event, payload)
      return skipped_result("release_gate_notification_cooldown_active") if recent_notification?(project, dedupe_key)

      deliver_and_record(
        project: project,
        actor_id: actor_id,
        event: event,
        payload: payload,
        dedupe_key: dedupe_key
      )
    end

    def notify_operation_executed(project:, actor_id:, operation_data:, audit_log_action:)
      payload = safe_payload(
        operation_data.merge(
          project_id: project.id,
          operator_actor_id: actor_id,
          audit_log_action: audit_log_action
        )
      )

      deliver_and_record(
        project: project,
        actor_id: actor_id,
        event: "failed_job_operation_executed",
        payload: payload,
        dedupe_key: nil
      )
    end

    private

    attr_reader :gateway, :clock, :release_gate_cooldown

    def deliver_and_record(project:, actor_id:, event:, payload:, dedupe_key:)
      gateway_result = gateway.deliver(event: event, payload: payload)
      return skipped_result(gateway_result.code, gateway_result.details) if gateway_result.status == "skipped"

      if gateway_result.success?
        record_delivery_audit!(
          project: project,
          actor_id: actor_id,
          action: "operations.failed_job_notification_sent",
          summary: "failed job運用通知を送信しました。",
          event: event,
          payload: payload,
          gateway_result: gateway_result,
          dedupe_key: dedupe_key
        )
        return success_result(gateway_result.details)
      end

      record_delivery_audit!(
        project: project,
        actor_id: actor_id,
        action: "operations.failed_job_notification_failed",
        summary: "failed job運用通知の送信に失敗しました。",
        event: event,
        payload: payload,
        gateway_result: gateway_result,
        dedupe_key: dedupe_key
      )
      failure_result(gateway_result.code, gateway_result.details)
    rescue ActiveRecord::ActiveRecordError
      failure_result("notification_audit_log_unavailable")
    end

    def record_delivery_audit!(project:, actor_id:, action:, summary:, event:, payload:, gateway_result:, dedupe_key:)
      AuditLog.record!(
        project: project,
        action: action,
        target: project,
        actor_id: actor_id,
        summary: summary,
        metadata: {
          event: event,
          channel: gateway_result.details.fetch(:channel, "operations"),
          delivery_status: gateway_result.status,
          delivery_code: gateway_result.code,
          http_status: gateway_result.details[:http_status],
          dedupe_key: dedupe_key,
          payload: payload
        }.compact
      )
    end

    def safe_payload(payload)
      payload.symbolize_keys
        .slice(*SAFE_PAYLOAD_KEYS)
        .transform_values { |value| safe_payload_value(value) }
        .compact
    end

    def safe_payload_value(value)
      case value
      when Array
        value.filter_map { |item| safe_payload_value(item) }
      when Hash
        value.symbolize_keys.slice(*SAFE_CHECK_KEYS).compact if value.key?(:key) || value.key?("key")
      when String, Numeric, TrueClass, FalseClass
        value
      else
        value.to_s if value.present?
      end
    end

    def notification_checks(release_gate)
      checks = release_gate_value(release_gate, :checks) || []
      checks.filter_map do |check|
        safe_payload_value(check)
      end
    end

    def release_gate_value(release_gate, key)
      release_gate[key] || release_gate[key.to_s]
    end

    def notification_dedupe_key(event, payload)
      Digest::SHA256.hexdigest("#{event}:#{payload.to_json}")
    end

    def recent_notification?(project, dedupe_key)
      return false if dedupe_key.blank?

      project.audit_logs
        .where(action: DELIVERY_AUDIT_ACTIONS)
        .where("created_at >= ?", clock.call - release_gate_cooldown)
        .order(created_at: :desc)
        .limit(20)
        .any? { |audit_log| audit_log.metadata&.fetch("dedupe_key", nil) == dedupe_key }
    end

    def success_result(details = {})
      Result.new(
        success?: true,
        status: "sent",
        code: "notification_sent",
        message: "運用通知を送信しました。",
        details: details
      )
    end

    def skipped_result(code, details = {})
      Result.new(
        success?: true,
        status: "skipped",
        code: code,
        message: "運用通知をスキップしました。",
        details: details
      )
    end

    def failure_result(code, details = {})
      Result.new(
        success?: false,
        status: "failed",
        code: code,
        message: "運用通知に失敗しました。",
        details: details
      )
    end
  end
end
