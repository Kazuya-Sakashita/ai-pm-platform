require "rails_helper"

RSpec.describe Operations::FailedJobNotificationService do
  describe "#notify_release_gate" do
    it "release gate warningをsafe payloadで送信しAuditLogへ記録する" do
      project = create(:project)
      gateway = gateway_double(status: "sent")
      release_gate = {
        status: "warning",
        checks: [
          {
            key: "failed_execution_count",
            label: "failed job残存件数",
            status: "warning",
            severity: "warning",
            observed_value: "5件",
            threshold: "5件未満",
            next_action: "release ownerが確認します。",
            raw_exception: "raw secret exception",
            token: "secret-token"
          }
        ]
      }

      result = described_class.new(gateway: gateway).notify_release_gate(
        project: project,
        release_gate: release_gate,
        actor_id: "system"
      )

      expect(result).to be_success
      expect(gateway).to have_received(:deliver).with(
        event: "release_gate_warning",
        payload: hash_including(
          project_id: project.id,
          release_gate_status: "warning",
          checks: [ hash_including(key: "failed_execution_count", status: "warning") ]
        )
      )

      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_notification_sent")
      expect(audit_log.actor_id).to eq("system")
      expect(audit_log.metadata).to include(
        "event" => "release_gate_warning",
        "channel" => "operations",
        "delivery_status" => "sent",
        "delivery_code" => "notification_sent"
      )
      expect(audit_log.metadata.dig("payload", "checks").first).not_to include("raw_exception", "token")
      expect(audit_log.metadata.to_s).not_to include("raw secret exception", "secret-token")
    end

    it "同じrelease gate通知をcooldown内で重複送信しない" do
      project = create(:project)
      gateway = gateway_double(status: "sent")
      service = described_class.new(gateway: gateway)
      release_gate = {
        status: "blocked",
        checks: [
          {
            key: "boundary_rejected_count",
            label: "Project境界拒否件数",
            status: "blocked",
            severity: "critical",
            observed_value: "1件",
            threshold: "0件",
            next_action: "Security Engineerが確認します。"
          }
        ]
      }

      first_result = service.notify_release_gate(project: project, release_gate: release_gate)
      second_result = service.notify_release_gate(project: project, release_gate: release_gate)

      expect(first_result.status).to eq("sent")
      expect(second_result.status).to eq("skipped")
      expect(second_result.code).to eq("release_gate_notification_cooldown_active")
      expect(gateway).to have_received(:deliver).once
    end

    it "pass状態では通知しない" do
      project = create(:project)
      gateway = gateway_double(status: "sent")

      result = described_class.new(gateway: gateway).notify_release_gate(
        project: project,
        release_gate: { status: "pass", checks: [] }
      )

      expect(result.status).to eq("skipped")
      expect(result.code).to eq("release_gate_notification_not_required")
      expect(gateway).not_to have_received(:deliver)
      expect(project.audit_logs).to be_empty
    end
  end

  describe "#notify_operation_executed" do
    it "通知失敗時にsafe metadataだけをAuditLogへ残す" do
      project = create(:project)
      gateway = gateway_double(status: "failed", code: "notification_http_error", details: { channel: "operations", http_status: 500 })

      result = described_class.new(gateway: gateway).notify_operation_executed(
        project: project,
        actor_id: "operator-1",
        audit_log_action: "operations.failed_job_retried",
        operation_data: {
          failed_job_id: 456,
          job_id: 123,
          queue_name: "github_reconciliation",
          class_name: "GithubIssuePublish::ReconciliationRetryJob",
          action: "retry",
          reason_template: "operator_confirmed_safe_retry",
          raw_exception: "raw exception",
          token: "secret-token",
          database_url: "postgres://secret"
        }
      )

      expect(result).not_to be_success
      expect(result.status).to eq("failed")

      audit_log = project.audit_logs.find_by!(action: "operations.failed_job_notification_failed")
      expect(audit_log.actor_id).to eq("operator-1")
      expect(audit_log.metadata).to include(
        "event" => "failed_job_operation_executed",
        "channel" => "operations",
        "delivery_status" => "failed",
        "delivery_code" => "notification_http_error",
        "http_status" => 500
      )
      expect(audit_log.metadata.dig("payload")).to include(
        "project_id" => project.id,
        "failed_job_id" => 456,
        "operator_actor_id" => "operator-1",
        "audit_log_action" => "operations.failed_job_retried"
      )
      expect(audit_log.metadata.to_s).not_to include("raw exception", "secret-token", "postgres://secret")
    end

    it "webhook未設定時はAuditLogを増やさずno-opする" do
      project = create(:project)
      gateway = gateway_double(status: "skipped", code: "webhook_url_not_configured")

      result = described_class.new(gateway: gateway).notify_operation_executed(
        project: project,
        actor_id: "operator-1",
        audit_log_action: "operations.failed_job_retried",
        operation_data: { failed_job_id: 456, action: "retry" }
      )

      expect(result).to be_success
      expect(result.status).to eq("skipped")
      expect(project.audit_logs).to be_empty
    end
  end

  def gateway_double(status:, code: nil, details: { channel: "operations", http_status: 200 })
    success = status != "failed"
    result = Operations::NotificationGateway::Result.new(
      success?: success,
      status: status,
      code: code || (success ? "notification_sent" : "notification_failed"),
      message: "test",
      details: details
    )
    instance_double(Operations::NotificationGateway, deliver: result)
  end
end
