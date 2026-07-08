require "spec_helper"
require "tmpdir"

require_relative "../../../backend/app/services/requirement_generation/provider_error"
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

  it "レビュー可能なRequirement出力をCritical failureなしで採点する" do
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

  it "禁止された生成内容をCritical failureとして記録する" do
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

RSpec.describe RequirementGenerationQuality::Evaluator do
  let(:case_one) do
    {
      "id" => "CASE-1",
      "title" => "case 1",
      "minutes" => { "summary" => "議事録1" },
      "expectations" => {}
    }
  end
  let(:case_two) do
    {
      "id" => "CASE-2",
      "title" => "case 2",
      "minutes" => { "summary" => "議事録2" },
      "expectations" => {}
    }
  end
  let(:fixtures) { { "cases" => [case_one, case_two] } }
  let(:provider) do
    Class.new do
      def generate(_minutes)
        {
          background: "議事録を根拠にする。",
          goal: "Requirement draftを生成する。",
          user_stories: ["ユーザーとして確認したい。"],
          functional_requirements: ["FR-001: Requirement draftを保存する。"],
          non_functional_requirements: ["監査できること。"],
          acceptance_criteria: ["保存できること。"],
          out_of_scope: ["完全自動承認。"],
          open_questions: ["承認者。"],
          risks: ["誤解釈。"],
          generated_by_model: "fake"
        }
      end
    end.new
  end
  let(:sleeper) { class_double("Kernel", sleep: nil) }

  it "完了済みcaseをyieldし、case間delayを適用する" do
    completed = []

    results = described_class.new(
      fixtures: fixtures,
      provider: provider,
      cases: [case_one, case_two],
      delay_seconds: 1.5,
      sleeper: sleeper
    ).call { |result| completed << result }

    expect(results.map(&:case_id)).to eq(%w[CASE-1 CASE-2])
    expect(completed.map(&:case_id)).to eq(%w[CASE-1 CASE-2])
    expect(sleeper).to have_received(:sleep).with(1.5).once
  end
end

RSpec.describe RequirementGenerationQuality::FailureReporter do
  it "ProviderErrorをsecret非出力のsafe reportにする" do
    error = RequirementGeneration::ProviderError.new(
      code: "rate_limit_exceeded",
      message: "raw secret token-never-print-this",
      safe_detail: "OpenAI request was rate limited. Retry after the provider limit resets.",
      http_status: :too_many_requests,
      request_id: "req_secret_like_value"
    )

    markdown = described_class.new(
      fixtures: { "issue" => "ISSUE-052", "version" => "v1" },
      provider_name: "openai",
      generated_at: "2026-07-08T03:40:00Z",
      error: error,
      selected_cases: [{ "id" => "CASE-RQ-001" }],
      completed_results: []
    ).markdown

    expect(markdown).to include("rate_limit_exceeded")
    expect(markdown).to include("request_id_present: true")
    expect(markdown).to include("--case-id CASE-RQ-001")
    expect(markdown).not_to include("token-never-print-this")
    expect(markdown).not_to include("req_secret_like_value")
  end

  it "safe resume manifestをsecret非出力で作成する" do
    error = RequirementGeneration::ProviderError.new(
      code: "insufficient_quota",
      message: "raw secret token-never-print-this",
      safe_detail: "OpenAI request was rate limited. Retry after the provider limit resets.",
      http_status: :too_many_requests,
      request_id: "req_secret_like_value"
    )
    completed_result = RequirementGenerationQuality::EvaluationResult.new(
      case_id: "CASE-RQ-000",
      title: "completed",
      score: 90,
      category_scores: {},
      critical_failures: [],
      findings: []
    )

    manifest = described_class.new(
      fixtures: { "issue" => "ISSUE-052", "version" => "v1" },
      provider_name: "openai",
      generated_at: "2026-07-08T03:40:00Z",
      error: error,
      selected_cases: [{ "id" => "CASE-RQ-000" }, { "id" => "CASE-RQ-001" }],
      completed_results: [completed_result]
    ).resume_manifest

    expect(manifest).to include(
      generated_at: "2026-07-08T03:40:00Z",
      fixture_issue: "ISSUE-052",
      fixture_version: "v1",
      provider: "openai",
      status: "safe_failure",
      selected_case_ids: %w[CASE-RQ-000 CASE-RQ-001],
      completed_case_ids: ["CASE-RQ-000"],
      next_case_id: "CASE-RQ-001"
    )
    expect(manifest.fetch(:safe_failure)).to include(
      error_code: "insufficient_quota",
      http_status: :too_many_requests,
      request_id_present: true
    )
    expect(manifest.fetch(:recommended_cli_args)).to include("--case-id", "CASE-RQ-001", "--delay-seconds", "10")
    expect(JSON.generate(manifest)).not_to include("token-never-print-this")
    expect(JSON.generate(manifest)).not_to include("req_secret_like_value")
  end
end

RSpec.describe RequirementGenerationQuality::Cli do
  it "case-idで評価対象caseを絞り込む" do
    cases = [
      { "id" => "CASE-1" },
      { "id" => "CASE-2" },
      { "id" => "CASE-3" }
    ]

    selected = described_class.select_cases(cases, case_ids: %w[CASE-3 CASE-1], limit: nil)

    expect(selected.map { |test_case| test_case.fetch("id") }).to eq(%w[CASE-3 CASE-1])
  end

  it "limitで評価対象case数を絞り込む" do
    cases = [
      { "id" => "CASE-1" },
      { "id" => "CASE-2" },
      { "id" => "CASE-3" }
    ]

    selected = described_class.select_cases(cases, case_ids: [], limit: 2)

    expect(selected.map { |test_case| test_case.fetch("id") }).to eq(%w[CASE-1 CASE-2])
  end

  it "OpenAI providerを評価providerとしてbuildできる" do
    provider = described_class.build_provider("openai")

    expect(provider).to be_a(RequirementGeneration::OpenaiProvider)
  end

  it "ProviderError時にsafe resume JSONをCLI経由で書き出す" do
    Dir.mktmpdir do |dir|
      fixture_path = File.join(dir, "cases.json")
      failure_output_path = File.join(dir, "failure.md")
      resume_output_path = File.join(dir, "resume.json")
      File.write(
        fixture_path,
        JSON.dump(
          "issue" => "ISSUE-052",
          "version" => "v1",
          "cases" => [
            {
              "id" => "CASE-RQ-001",
              "title" => "OpenAI live評価",
              "minutes" => { "summary" => "議事録サマリー" },
              "expectations" => {}
            }
          ]
        )
      )
      provider = Class.new do
        def generate(_minutes)
          raise RequirementGeneration::ProviderError.new(
            code: "insufficient_quota",
            message: "raw secret token-never-print-this",
            safe_detail: "OpenAI request was rate limited. Retry after the provider limit resets.",
            http_status: :too_many_requests,
            request_id: "req_secret_like_value"
          )
        end
      end.new
      allow(described_class).to receive(:build_provider).with("openai").and_return(provider)

      exit_code = nil
      expect do
        exit_code = described_class.run(
          [
            "--fixtures", fixture_path,
            "--provider", "openai",
            "--case-id", "CASE-RQ-001",
            "--failure-output", failure_output_path,
            "--resume-output", resume_output_path,
            "--quiet"
          ]
        )
      end.to output(/safe failure insufficient_quota/).to_stderr

      manifest_json = File.read(resume_output_path)
      manifest = JSON.parse(manifest_json)
      failure_markdown = File.read(failure_output_path)
      expect(exit_code).to eq(1)
      expect(manifest).to include(
        "fixture_issue" => "ISSUE-052",
        "fixture_version" => "v1",
        "provider" => "openai",
        "status" => "safe_failure",
        "selected_case_ids" => ["CASE-RQ-001"],
        "completed_case_ids" => [],
        "next_case_id" => "CASE-RQ-001"
      )
      expect(manifest.fetch("safe_failure")).to include(
        "error_code" => "insufficient_quota",
        "http_status" => "too_many_requests",
        "request_id_present" => true
      )
      expect(manifest.fetch("recommended_cli_args")).to include("--case-id", "CASE-RQ-001", "--delay-seconds", "10")
      expect(manifest_json).not_to include("token-never-print-this")
      expect(manifest_json).not_to include("req_secret_like_value")
      expect(failure_markdown).to include("insufficient_quota")
    end
  end
end
