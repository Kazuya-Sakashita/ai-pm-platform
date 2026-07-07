require "rails_helper"

RSpec.describe Operations::NotificationGateway do
  describe "#deliver" do
    it "webhook URL未設定では安全にno-opする" do
      result = described_class.new(webhook_url: nil).deliver(
        event: "release_gate_warning",
        payload: { project_id: SecureRandom.uuid }
      )

      expect(result).to be_success
      expect(result.status).to eq("skipped")
      expect(result.code).to eq("webhook_url_not_configured")
      expect(result.details).to include(channel: "operations")
    end

    it "不正なwebhook URLを送信せず失敗扱いにする" do
      result = described_class.new(webhook_url: "not-a-url").deliver(
        event: "release_gate_blocked",
        payload: { project_id: SecureRandom.uuid, token: "secret-token" }
      )

      expect(result).not_to be_success
      expect(result.status).to eq("failed")
      expect(result.code).to eq("webhook_url_invalid")
      expect(result.details.to_s).not_to include("not-a-url")
      expect(result.details.to_s).not_to include("secret-token")
    end
  end
end
