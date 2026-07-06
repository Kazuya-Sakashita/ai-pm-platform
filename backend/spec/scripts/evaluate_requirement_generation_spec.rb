require "spec_helper"

require_relative "../../../scripts/evaluate-requirement-generation"

RSpec.describe RequirementGenerationQuality::CaseEvaluator do
  let(:test_case) do
    {
      "id" => "CASE-TEST",
      "title" => "評価fixture",
      "expectations" => {
        "source_terms" => ["承認済みMinutes", "Requirement draft"],
        "open_question_terms" => ["承認者"],
        "acceptance_terms" => ["保存"],
        "out_of_scope_terms" => ["完全自動承認"],
        "non_functional_terms" => ["監査"],
        "min_counts" => {
          "functional_requirements" => 1,
          "acceptance_criteria" => 1,
          "out_of_scope" => 1,
          "risks" => 1
        },
        "forbidden_patterns" => ["レビューなしで実装"]
      }
    }
  end

  it "scores a reviewable requirement output without critical failures" do
    output = {
      background: "議事録サマリー: 承認済みMinutesからRequirement draftを作る。",
      goal: "承認済みMinutesからRequirement draftを生成する。",
      user_stories: ["プロジェクトメンバーとして、Requirement draftを確認したい。"],
      functional_requirements: ["FR-001: Requirement draftを保存する。"],
      non_functional_requirements: ["生成元Minutesとレビュー結果を監査できること。"],
      acceptance_criteria: ["承認済み議事録から生成したとき、Requirement draftが保存されている。"],
      out_of_scope: ["完全自動承認。"],
      open_questions: ["承認者を誰にするか。"],
      risks: ["レビュー前提であるため誤解釈が残る可能性がある。"],
      generated_by_model: "deterministic-test"
    }

    result = described_class.new(test_case: test_case, output: output).call

    expect(result.score).to be >= 90
    expect(result.critical_failures).to eq([])
  end

  it "records critical failures for forbidden generated content" do
    output = {
      background: "議事録サマリー: 承認済みMinutesからRequirement draftを作る。",
      goal: "レビューなしで実装へ進める。",
      user_stories: ["プロジェクトメンバーとして、Requirement draftを確認したい。"],
      functional_requirements: ["FR-001: Requirement draftを保存する。"],
      non_functional_requirements: ["生成元Minutesとレビュー結果を監査できること。"],
      acceptance_criteria: ["承認済み議事録から生成したとき、Requirement draftが保存されている。"],
      out_of_scope: ["完全自動承認。"],
      open_questions: ["承認者を誰にするか。"],
      risks: ["レビュー前提であるため誤解釈が残る可能性がある。"],
      generated_by_model: "deterministic-test"
    }

    result = described_class.new(test_case: test_case, output: output).call

    expect(result.critical_failures).to include("禁止patternに一致: レビューなしで実装")
  end
end
