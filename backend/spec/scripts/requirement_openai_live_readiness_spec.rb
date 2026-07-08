require "json"
require "spec_helper"
require "stringio"

require_relative "../../../scripts/requirement-openai-live-readiness"

RSpec.describe RequirementOpenaiLiveReadiness do
  def run_readiness(env:, argv: [])
    stdout = StringIO.new
    stderr = StringIO.new
    status = described_class.new(env: env, stdout: stdout, stderr: stderr).run(argv)

    [status, JSON.parse(stdout.string), stderr.string]
  end

  it "OpenAI live評価に必要な未設定項目をsafe failureとnext actionで返す" do
    status, payload, stderr = run_readiness(env: {})

    expect(status).to eq(1)
    expect(stderr).to eq("")
    expect(payload.fetch("safe_failures")).to include(
      "openai_api_key_missing",
      "openai_requirement_model_missing"
    )
    expect(payload.fetch("next_actions")).to include(
      "OPENAI_API_KEYを安全なsecret storeまたはローカル.envへ設定する。",
      "OPENAI_REQUIREMENT_MODELをlive評価対象モデル名で設定する。"
    )
  end

  it "API keyの値を出力しない" do
    status, payload, = run_readiness(
      env: {
        "OPENAI_API_KEY" => "sk-never-print-this-secret-value",
        "OPENAI_REQUIREMENT_MODEL" => "gpt-test"
      }
    )

    expect(status).to eq(0)
    expect(payload.fetch("openai_api_key_configured")).to eq(true)
    expect(payload.fetch("openai_requirement_model_configured")).to eq(true)
    expect(payload.to_json).not_to include("sk-never-print-this-secret-value")
  end

  it "insecure endpointをsafe failureにする" do
    status, payload, = run_readiness(
      env: {
        "OPENAI_API_KEY" => "sk-never-print-this-secret-value",
        "OPENAI_REQUIREMENT_MODEL" => "gpt-test",
        "OPENAI_RESPONSES_URL" => "http://api.openai.com/v1/responses?token=secret"
      }
    )

    expect(status).to eq(1)
    expect(payload.fetch("safe_failures")).to include("openai_responses_url_invalid_or_insecure")
    expect(payload.fetch("openai_responses_url")).to eq("http://api.openai.com/v1/responses")
    expect(payload.to_json).not_to include("token=secret")
  end
end
