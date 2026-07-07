require "rails_helper"

RSpec.describe RequirementGenerationService do
  around do |example|
    with_env("REQUIREMENT_GENERATION_PROVIDER" => "deterministic", "OPENAI_API_KEY" => nil) do
      example.run
    end
  end

  it "creates an editable requirement draft from approved minutes" do
    minutes = create(
      :minute,
      status: "approved",
      summary: "レビューゲートを強制する必要がある。",
      decisions: [{ "text" => "承認後のみ要件定義を生成する。" }],
      open_questions: ["要件レビューの責任者は誰か。"],
      action_items: [{ "text" => "要件エディタを作成する。", "status" => "open" }]
    )

    requirement = described_class.new(minutes).call

    expect(requirement).to be_persisted
    expect(requirement.status).to eq("generated")
    expect(requirement.background).to include("レビューゲート")
    expect(requirement.goal).to include("承認後のみ要件定義を生成")
    expect(requirement.user_stories.first).to include("プロジェクトメンバーとして")
    expect(requirement.functional_requirements).to include(/承認後のみ要件定義を生成/)
    expect(requirement.acceptance_criteria.first).to include("承認済み議事録から要件定義を生成")
    expect(requirement.open_questions).to include("要件レビューの責任者は誰か。")
    expect(requirement.generated_by_model).to eq("deterministic-requirements-placeholder-v1")
  end

  it "uses an injected provider" do
    minutes = create(:minute, status: "approved")
    provider = instance_double(
      RequirementGeneration::DeterministicProvider,
      generate: {
        status: "generated",
        background: "Custom background",
        goal: "Custom goal",
        functional_requirements: ["Custom functional requirement"],
        acceptance_criteria: ["Custom acceptance criterion"],
        generated_by_model: "provider-test"
      }
    )

    requirement = described_class.new(minutes, provider: provider).call

    expect(requirement.background).to eq("Custom background")
    expect(requirement.functional_requirements).to eq(["Custom functional requirement"])
    expect(requirement.generated_by_model).to eq("provider-test")
  end

  it "uses provider factory when provider is omitted" do
    minutes = create(:minute, status: "approved")
    provider = instance_double(
      RequirementGeneration::DeterministicProvider,
      generate: {
        status: "generated",
        background: "Factory background",
        goal: "Factory goal",
        functional_requirements: ["FR-001: Factory requirement"],
        acceptance_criteria: ["Factory acceptance criterion"],
        generated_by_model: "factory-provider-test"
      }
    )
    allow(RequirementGeneration::ProviderFactory).to receive(:build).and_return(provider)

    requirement = described_class.new(minutes).call

    expect(requirement.background).to eq("Factory background")
    expect(requirement.generated_by_model).to eq("factory-provider-test")
  end

  it "blocks sensitive requirement source before calling provider" do
    minutes = create(:minute, status: "approved", summary: "password=super-secret-value を使う。")
    provider = instance_double(RequirementGeneration::DeterministicProvider)
    expect(provider).not_to receive(:generate)

    expect do
      described_class.new(minutes, provider: provider).call
    end.to raise_error(RequirementGeneration::ProviderError) { |error|
      expect(error.code).to eq("sensitive_content_blocked")
      expect(error.safe_detail).to eq("要件定義生成に使う議事録に機密性の高い内容が含まれています。AI生成前にレビューしてください。")
      expect(error.http_status).to eq(:unprocessable_entity)
    }

    expect(minutes.requirements).to be_empty
  end
end
