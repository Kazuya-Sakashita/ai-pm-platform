require "rails_helper"

RSpec.describe RequirementGeneration::ProviderFactory do
  it "defaults to deterministic provider" do
    with_env("REQUIREMENT_GENERATION_PROVIDER" => nil) do
      expect(described_class.build).to be_a(RequirementGeneration::DeterministicProvider)
    end
  end

  it "uses OpenAI provider only when explicitly configured" do
    with_env("REQUIREMENT_GENERATION_PROVIDER" => "openai") do
      expect(described_class.build).to be_a(RequirementGeneration::OpenaiProvider)
    end
  end

  it "uses deterministic provider in explicit auto mode when OpenAI is not configured" do
    with_env("REQUIREMENT_GENERATION_PROVIDER" => "auto", "OPENAI_API_KEY" => nil) do
      expect(described_class.build).to be_a(RequirementGeneration::DeterministicProvider)
    end
  end

  it "uses OpenAI provider in explicit auto mode only when OpenAI is configured" do
    with_env("REQUIREMENT_GENERATION_PROVIDER" => "auto", "OPENAI_API_KEY" => "test-key") do
      expect(described_class.build).to be_a(RequirementGeneration::OpenaiProvider)
    end
  end

  it "raises a safe error for unsupported provider names" do
    with_env("REQUIREMENT_GENERATION_PROVIDER" => "unknown") do
      expect do
        described_class.build
      end.to raise_error(RequirementGeneration::ProviderError) { |error|
        expect(error.code).to eq("requirement_provider_not_supported")
        expect(error.safe_detail).to eq("Requirement generation provider is not supported.")
        expect(error.http_status).to eq(:unprocessable_entity)
      }
    end
  end
end
