require "rails_helper"

RSpec.describe GithubIntegration::WebhookRequestGuard do
  let!(:store) { ActiveSupport::Cache::MemoryStore.new }
  let!(:now) { Time.zone.local(2026, 7, 7, 21, 30, 0) }
  let!(:clock) { -> { now } }
  let!(:rate_limiter) do
    GithubIntegration::WebhookRateLimiter.new(
      store: store,
      limit: 1,
      window_seconds: 60,
      clock: clock
    )
  end
  let!(:guard) { described_class.new(max_bytes: 10, rate_limiter: rate_limiter) }

  it "Content-Lengthが上限を超える場合は413で拒否する" do
    expect_webhook_error(
      code: "github_webhook_payload_too_large",
      http_status: :payload_too_large
    ) { guard.check_content_length!("11") }
  end

  it "Content-Lengthが上限以下なら通す" do
    expect(guard.check_content_length!("10")).to eq(true)
    expect(guard.check_content_length!(nil)).to eq(true)
  end

  it "raw payloadのbytesizeが上限を超える場合は413で拒否する" do
    expect_webhook_error(
      code: "github_webhook_payload_too_large",
      http_status: :payload_too_large
    ) { guard.check_payload_size!("0123456789x") }
  end

  it "raw payloadのbytesizeが上限ちょうどなら通す" do
    expect(guard.check_payload_size!("0123456789")).to eq(true)
  end

  it "remote IP単位のrate limit超過を429で拒否する" do
    expect(guard.check_rate_limit!(remote_ip: "203.0.113.10")).to eq(true)

    expect_webhook_error(
      code: "github_webhook_rate_limited",
      http_status: :too_many_requests,
      headers: { "Retry-After" => "60" }
    ) { guard.check_rate_limit!(remote_ip: "203.0.113.10") }
  end

  it "別remote IPは同じwindowでも別枠で通す" do
    expect(guard.check_rate_limit!(remote_ip: "203.0.113.10")).to eq(true)
    expect(guard.check_rate_limit!(remote_ip: "203.0.113.11")).to eq(true)
  end

  def expect_webhook_error(code:, http_status:, headers: {})
    yield
    raise "expected GithubIntegration::WebhookError"
  rescue GithubIntegration::WebhookError => error
    expect(error.code).to eq(code)
    expect(error.http_status).to eq(http_status)
    headers.each { |key, value| expect(error.headers[key]).to eq(value) }
  end
end
