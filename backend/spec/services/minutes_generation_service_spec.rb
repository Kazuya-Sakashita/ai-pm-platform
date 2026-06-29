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
end
