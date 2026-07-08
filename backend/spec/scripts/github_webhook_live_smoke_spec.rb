require "json"
require "spec_helper"
require "stringio"

require_relative "../../../scripts/github-webhook-live-smoke"

RSpec.describe GithubWebhookLiveSmoke do
  def run_smoke(env)
    stdout = StringIO.new
    stderr = StringIO.new
    status = described_class.new(env: env, stdout: stdout, stderr: stderr).run(["--limit", "1"])

    [status, JSON.parse(stdout.string), stderr.string]
  end

  it "GitHub App設定不足をsafe failureとnext actionで返す" do
    status, payload, stderr = run_smoke({
      "GITHUB_APP_ID" => "",
      "GITHUB_APP_PRIVATE_KEY_BASE64" => "",
      "GITHUB_WEBHOOK_SECRET" => ""
    })

    expect(status).to eq(1)
    expect(stderr).to eq("")
    expect(payload.fetch("safe_failures")).to include(
      "github_app_id_missing",
      "github_app_private_key_missing",
      "github_webhook_secret_missing"
    )
    expect(payload.fetch("next_actions")).to include(
      "GITHUB_APP_IDをruntimeへ設定する。",
      "GITHUB_APP_PRIVATE_KEY_BASE64またはGITHUB_APP_PRIVATE_KEYをruntimeへ設定する。",
      "GitHub App settingsのWebhook secretと同じ値をGITHUB_WEBHOOK_SECRETへ設定する。"
    )
  end

  it "webhook secretの値を出力しない" do
    status, payload, = run_smoke({
      "GITHUB_APP_ID" => "",
      "GITHUB_APP_PRIVATE_KEY_BASE64" => "",
      "GITHUB_WEBHOOK_SECRET" => "raw-webhook-secret"
    })

    expect(status).to eq(1)
    expect(payload.to_json).not_to include("raw-webhook-secret")
    expect(payload.fetch("webhook_secret_configured")).to eq(true)
  end
end
