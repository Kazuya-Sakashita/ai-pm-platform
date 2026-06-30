require "rails_helper"

RSpec.describe MinutesGenerationService do
  it "persists minutes from an injected provider" do
    meeting = create(:meeting)
    provider = instance_double(
      "MinutesProvider",
      generate: {
        status: "generated",
        summary: "Provider summary",
        decisions: [{ text: "Provider decision" }],
        open_questions: ["Provider question"],
        action_items: [{ text: "Provider action", status: "open" }],
        generated_by_model: "provider-test"
      }
    )

    minute = described_class.new(meeting, provider: provider).call

    expect(minute.summary).to eq("Provider summary")
    expect(minute.generated_by_model).to eq("provider-test")
    expect(minute.decisions.first.fetch("text")).to eq("Provider decision")
  end

  it "blocks sensitive content before calling the provider" do
    meeting = create(:meeting, raw_text: "Authorization: Bearer secret-token")
    provider = spy("MinutesProvider")

    expect do
      described_class.new(meeting, provider: provider).call
    end.to raise_error(MinutesGeneration::ProviderError) { |error|
      expect(error.code).to eq("sensitive_content_blocked")
      expect(error.http_status).to eq(:unprocessable_entity)
    }
    expect(provider).not_to have_received(:generate)
  end
end
