require "rails_helper"
require "openssl"

RSpec.describe GithubIntegration::WebhookSignatureVerifier do
  let!(:payload) { JSON.generate(action: "deleted", installation: { id: 123_456 }) }
  let!(:secret) { "webhook-secret" }
  let!(:signature) { "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", secret, payload)}" }

  it "raw bodyのHMAC SHA-256署名を検証する" do
    verifier = described_class.new(secret: secret)

    expect(verifier.verify!(payload: payload, signature: signature)).to eq(true)
  end

  it "改ざんされた署名を拒否する" do
    verifier = described_class.new(secret: secret)

    expect do
      verifier.verify!(payload: payload, signature: "sha256=invalid")
    end.to raise_error(GithubIntegration::WebhookError) { |error|
      expect(error.code).to eq("github_webhook_signature_invalid")
      expect(error.safe_detail).to eq("GitHub Webhook署名が不正です。")
      expect(error.http_status).to eq(:unauthorized)
    }
  end

  it "rotation window中はprevious secretの署名も検証する" do
    previous_secret = "previous-webhook-secret"
    previous_signature = "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", previous_secret, payload)}"
    verifier = described_class.new(secret: secret, previous_secret: previous_secret)

    expect(verifier.verify!(payload: payload, signature: previous_signature)).to eq(true)
  end

  it "secret未設定では安全に失敗する" do
    verifier = described_class.new(secret: nil, previous_secret: nil)

    expect do
      verifier.verify!(payload: payload, signature: signature)
    end.to raise_error(GithubIntegration::WebhookError) { |error|
      expect(error.code).to eq("github_webhook_secret_not_configured")
      expect(error.safe_detail).to eq("GitHub Webhook secretが設定されていません。")
      expect(error.http_status).to eq(:unauthorized)
    }
  end
end
