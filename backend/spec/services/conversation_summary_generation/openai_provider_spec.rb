require "rails_helper"

RSpec.describe ConversationSummaryGeneration::OpenaiProvider do
  it "normalizes a structured Responses API result and sends redacted text only" do
    conversation_import = create(
      :conversation_import,
      raw_text: "password=hunter2 を使う。決定: DM整理を実装する。",
      redacted_text: "[PASSWORD_REDACTED] を使う。決定: DM整理を実装する。",
      participants: [{ display_name: "依頼者", role: "requester" }]
    )
    captured_payload = nil
    http_client = lambda do |payload|
      captured_payload = payload
      [
        200,
        {
          output_text: JSON.generate(
            summary: "DM整理provider接続を進める。",
            decisions: [
              { text: "DM整理をStructured Outputsへ接続する。", owner: "Tech Lead", source_quote_ids: ["q1"], confidence: 0.91 }
            ],
            open_questions: ["manual smokeの担当者を確認する。"],
            action_items: [
              { text: "provider specを追加する。", owner: "Backend", due_date: nil, status: "open", source_quote_ids: ["q1"], confidence: 0.88 }
            ],
            issue_candidates: [
              {
                title: "DM整理Structured Outputs provider",
                body: "DM整理をOpenAI providerへ接続する。",
                labels: ["ai", "discord-dm"],
                priority: "P1",
                source_quote_ids: ["q1"],
                confidence: 0.86
              }
            ],
            requirement_candidates: [
              {
                title: "DM整理provider contract",
                requirement: "AI応答はschemaに準拠する。",
                acceptance_criteria: ["invalid responseをsafe errorにする。"],
                source_quote_ids: ["q1"],
                confidence: 0.84
              }
            ],
            risks: [
              { text: "PIIをAIへ送信するリスク。", severity: "high", mitigation: "scan gateで止める。", source_quote_ids: ["q1"], confidence: 0.82 }
            ],
            participants: [
              { display_name: "依頼者", handle: nil, role: "requester", notes: nil }
            ],
            source_quotes: [
              { id: "q1", quote: "決定: DM整理を実装する。", speaker: "依頼者", message_at: nil }
            ],
            confidence: 0.9
          )
        }.to_json,
        "req_dm_summary"
      ]
    end

    result = described_class.new(api_key: "test-key", model: "gpt-test", http_client: http_client).generate(conversation_import)

    expect(result.fetch(:provider)).to eq("openai")
    expect(result.fetch(:model)).to eq("gpt-test")
    expect(result.fetch(:summary)).to include("provider接続")
    expect(result.fetch(:decisions).first).to include(text: "DM整理をStructured Outputsへ接続する。", confidence: 0.91)
    expect(result.fetch(:action_items).first).to include(status: "open", source_quote_ids: ["q1"])
    expect(result.fetch(:issue_candidates).first).to include(priority: "P1")
    expect(result.fetch(:requirement_candidates).first.fetch(:acceptance_criteria)).to include("invalid responseをsafe errorにする。")
    expect(result.fetch(:risks).first).to include(severity: "high")
    expect(result.fetch(:source_quotes).first.fetch(:quote)).to include("DM整理")
    expect(JSON.generate(captured_payload)).to include("[PASSWORD_REDACTED]")
    expect(JSON.generate(captured_payload)).not_to include("hunter2")
    expect(captured_payload.dig(:text, :format, :strict)).to eq(true)
    expect(captured_payload.dig(:text, :format, :schema, :additionalProperties)).to eq(false)
  end

  it "returns a safe provider error for malformed model output" do
    conversation_import = create(:conversation_import)
    http_client = ->(_payload) { [200, { output_text: "not json" }.to_json, "req_bad"] }

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(conversation_import)
    end.to raise_error(ConversationSummaryGeneration::ProviderError) { |error|
      expect(error.code).to eq("invalid_ai_response")
      expect(error.safe_detail).to eq("AI response did not match the expected DM summary schema.")
      expect(error.http_status).to eq(:bad_gateway)
      expect(error.request_id).to eq("req_bad")
    }
  end

  it "maps OpenAI rate limits to a retryable safe error" do
    conversation_import = create(:conversation_import)
    http_client = lambda do |_payload|
      [
        429,
        { error: { code: "rate_limit_exceeded" } }.to_json,
        "req_rate"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(conversation_import)
    end.to raise_error(ConversationSummaryGeneration::ProviderError) { |error|
      expect(error.code).to eq("rate_limit_exceeded")
      expect(error.safe_detail).to eq("OpenAI request was rate limited. Retry after the provider limit resets.")
      expect(error.http_status).to eq(:too_many_requests)
      expect(error.request_id).to eq("req_rate")
    }
  end

  it "maps upstream OpenAI errors to a safe provider error" do
    conversation_import = create(:conversation_import)
    http_client = lambda do |_payload|
      [
        500,
        { error: { type: "server_error" } }.to_json,
        "req_upstream"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(conversation_import)
    end.to raise_error(ConversationSummaryGeneration::ProviderError) { |error|
      expect(error.code).to eq("server_error")
      expect(error.safe_detail).to eq("OpenAI request failed. Retry later or check integration settings.")
      expect(error.http_status).to eq(:bad_gateway)
      expect(error.request_id).to eq("req_upstream")
    }
  end

  it "requires an OpenAI API key when forced" do
    conversation_import = create(:conversation_import)

    expect do
      described_class.new(api_key: nil).generate(conversation_import)
    end.to raise_error(ConversationSummaryGeneration::ProviderError) { |error|
      expect(error.code).to eq("integration_not_connected")
      expect(error.safe_detail).to eq("OpenAI API key is not configured.")
      expect(error.http_status).to eq(:failed_dependency)
    }
  end
end
