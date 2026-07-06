require "rails_helper"

RSpec.describe RequirementGeneration::DeterministicProvider do
  let(:minutes_class) { Struct.new(:summary, :decisions, :open_questions, :action_items, keyword_init: true) }

  it "extracts security and privacy non functional requirements" do
    minutes = minutes_class.new(
      summary: "Discordログにはメールアドレス、個人名、API keyらしき文字列が含まれる。SSOはMVP外とする。",
      decisions: [{ "text" => "Requirement本文に機微情報を直接残さない。" }],
      open_questions: ["PIIマスキングの承認者を誰にするか。"],
      action_items: [{ "text" => "secret scanとPIIマスキングを生成前後で確認する。" }]
    )

    output = described_class.new.generate(minutes)

    expect(output.fetch(:non_functional_requirements).join("\n")).to include("secret scan", "PIIマスキング", "権限境界", "監査ログ")
    expect(output.fetch(:out_of_scope)).to include("SSO実装はMVP外。")
  end

  it "extracts downstream implementation and CI automation boundaries" do
    minutes = minutes_class.new(
      summary: "Backend/Frontend実装は次工程とする。初期MVPでは自動採点を警告扱いにし、CI上で品質低下を検知する。",
      decisions: [{ "text" => "合格しない生成結果はIssue化前にレビューする。" }],
      open_questions: ["品質低下をCIでどの閾値から通知するか。"],
      action_items: [{ "text" => "レビュー担当がRequirement差分を短時間で確認できるようにする。" }]
    )

    output = described_class.new.generate(minutes)

    expect(output.fetch(:non_functional_requirements).join("\n")).to include("CI", "警告", "差分", "UX")
    expect(output.fetch(:out_of_scope)).to include(
      "Backend/Frontend実装は今回のRequirement生成評価の非スコープ。",
      "初期MVPでの自動採点による完全自動ブロック。"
    )
  end

  it "does not reuse source text between generate calls" do
    provider = described_class.new
    first_minutes = minutes_class.new(
      summary: "GitHub Issue化は次フェーズでよい。",
      decisions: [],
      open_questions: [],
      action_items: []
    )
    second_minutes = minutes_class.new(
      summary: "SSOはMVP外とする。",
      decisions: [{ "text" => "監査ログは保持する。" }],
      open_questions: [],
      action_items: []
    )

    provider.generate(first_minutes)
    output = provider.generate(second_minutes)

    expect(output.fetch(:out_of_scope)).to include("SSO実装はMVP外。")
  end
end
