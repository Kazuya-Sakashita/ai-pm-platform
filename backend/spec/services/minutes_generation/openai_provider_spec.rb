require "rails_helper"

RSpec.describe MinutesGeneration::OpenaiProvider do
  it "normalizes a structured Responses API result" do
    meeting = create(:meeting, raw_text: "Decision: launch the MVP.")
    http_client = lambda do |_payload|
      [
        200,
        {
          output_text: JSON.generate(
            summary: "Launch was discussed.",
            decisions: [{ text: "Launch the MVP.", owner: "Product" }],
            open_questions: ["What is the release date?"],
            action_items: [{ text: "Prepare release notes.", owner: "PM", due_date: nil, status: "open" }]
          )
        }.to_json,
        "req_test"
      ]
    end

    result = described_class.new(api_key: "test-key", model: "gpt-test", http_client: http_client).generate(meeting)

    expect(result.fetch(:summary)).to eq("Launch was discussed.")
    expect(result.fetch(:decisions).first).to eq(text: "Launch the MVP.", owner: "Product")
    expect(result.fetch(:open_questions).first).to include("release date")
    expect(result.fetch(:action_items).first).to eq(text: "Prepare release notes.", owner: "PM", status: "open")
    expect(result.fetch(:generated_by_model)).to eq("gpt-test")
  end

  it "returns a safe provider error for malformed model output" do
    meeting = create(:meeting)
    http_client = ->(_payload) { [200, { output_text: "not json" }.to_json, "req_bad"] }

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(meeting)
    end.to raise_error(MinutesGeneration::ProviderError) { |error|
      expect(error.code).to eq("invalid_ai_response")
      expect(error.safe_detail).to eq("AI response did not match the expected minutes schema.")
      expect(error.request_id).to eq("req_bad")
    }
  end

  it "maps OpenAI rate limits to a retryable safe error" do
    meeting = create(:meeting)
    http_client = lambda do |_payload|
      [
        429,
        { error: { code: "rate_limit_exceeded" } }.to_json,
        "req_rate"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(meeting)
    end.to raise_error(MinutesGeneration::ProviderError) { |error|
      expect(error.code).to eq("rate_limit_exceeded")
      expect(error.safe_detail).to eq("OpenAI request was rate limited. Retry after the provider limit resets.")
      expect(error.http_status).to eq(:too_many_requests)
      expect(error.request_id).to eq("req_rate")
    }
  end

  it "maps upstream OpenAI errors to a safe provider error" do
    meeting = create(:meeting)
    http_client = lambda do |_payload|
      [
        500,
        { error: { type: "server_error" } }.to_json,
        "req_upstream"
      ]
    end

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(meeting)
    end.to raise_error(MinutesGeneration::ProviderError) { |error|
      expect(error.code).to eq("server_error")
      expect(error.safe_detail).to eq("OpenAI request failed. Retry later or check integration settings.")
      expect(error.http_status).to eq(:bad_gateway)
      expect(error.request_id).to eq("req_upstream")
    }
  end
end
