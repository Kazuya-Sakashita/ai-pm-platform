require "rails_helper"

RSpec.describe SensitiveContentScanner do
  it "blocks known secret patterns" do
    result = described_class.scan("Please use password=hunter2 for the demo.")

    expect(result).to be_blocked
    expect(result.finding_types).to include("password")
  end

  it "marks normal meeting text as clear" do
    result = described_class.scan("Decision: ship the review workflow first.")

    expect(result.status).to eq("clear")
    expect(result.findings).to be_empty
  end
end
