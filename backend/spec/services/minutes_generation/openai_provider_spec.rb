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

  it "blocks sensitive content before calling OpenAI" do
    meeting = create(:meeting, raw_text: "Authorization: Bearer secret-token")
    http_client = instance_double(Proc)

    expect do
      described_class.new(api_key: "test-key", http_client: http_client).generate(meeting)
    end.to raise_error(MinutesGeneration::ProviderError) { |error|
      expect(error.code).to eq("sensitive_content_blocked")
      expect(error.http_status).to eq(:unprocessable_entity)
    }
  end
end
