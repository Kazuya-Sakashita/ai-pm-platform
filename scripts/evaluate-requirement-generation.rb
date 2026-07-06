#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "time"

module RequirementGenerationQuality
  ROOT = File.expand_path("..", __dir__)
  DEFAULT_FIXTURE_PATH = File.join(ROOT, "docs/evaluation/fixtures/requirement_generation/cases.json")
  DEFAULT_PROVIDER = "deterministic"

  RUBRIC = {
    fidelity: 15,
    structure: 10,
    traceability: 12,
    ambiguity: 12,
    acceptance: 12,
    scope: 12,
    non_functional: 10,
    readiness: 10,
    readability: 5,
    generated_by_model: 2
  }.freeze

  P0_CATEGORY_LABELS = {
    fidelity: "会議内容への忠実性",
    ambiguity: "未決事項と矛盾検出",
    acceptance: "受け入れ条件の検証可能性",
    scope: "スコープ制御と幻覚耐性",
    non_functional: "非機能、セキュリティ、監査"
  }.freeze

  MinutesInput = Struct.new(:summary, :decisions, :open_questions, :action_items, keyword_init: true)
  EvaluationResult = Struct.new(:case_id, :title, :score, :category_scores, :critical_failures, :findings, keyword_init: true)

  class Evaluator
    def initialize(fixtures:, provider:)
      @fixtures = fixtures
      @provider = provider
    end

    def call
      fixtures.fetch("cases").map do |test_case|
        output = provider.generate(minutes_from(test_case.fetch("minutes")))
        CaseEvaluator.new(test_case: test_case, output: output).call
      end
    end

    private

    attr_reader :fixtures, :provider

    def minutes_from(data)
      MinutesInput.new(
        summary: data.fetch("summary", ""),
        decisions: data.fetch("decisions", []),
        open_questions: data.fetch("open_questions", []),
        action_items: data.fetch("action_items", [])
      )
    end
  end

  class CaseEvaluator
    def initialize(test_case:, output:)
      @test_case = test_case
      @output = stringify_keys(output)
      @expectations = test_case.fetch("expectations", {})
      @findings = []
      @critical_failures = []
    end

    def call
      category_scores = {
        fidelity: score_terms(:fidelity, "source_terms", text_blob, "入力Minutesの重要語"),
        structure: score_structure,
        traceability: score_traceability,
        ambiguity: score_terms(:ambiguity, "open_question_terms", Array(output["open_questions"]).join("\n"), "未決事項"),
        acceptance: score_acceptance,
        scope: score_terms(:scope, "out_of_scope_terms", Array(output["out_of_scope"]).join("\n"), "スコープ外"),
        non_functional: score_terms(:non_functional, "non_functional_terms", Array(output["non_functional_requirements"]).join("\n"), "非機能要件"),
        readiness: score_readiness,
        readability: score_readability,
        generated_by_model: score_generated_by_model
      }

      detect_forbidden_patterns

      EvaluationResult.new(
        case_id: test_case.fetch("id"),
        title: test_case.fetch("title"),
        score: category_scores.values.sum.round(1),
        category_scores: category_scores.transform_values { |score| score.round(1) },
        critical_failures: critical_failures,
        findings: findings
      )
    end

    private

    attr_reader :test_case, :output, :expectations, :findings, :critical_failures

    def stringify_keys(value)
      case value
      when Hash
        value.to_h { |key, child| [key.to_s, stringify_keys(child)] }
      when Array
        value.map { |child| stringify_keys(child) }
      else
        value
      end
    end

    def text_blob
      [
        output["background"],
        output["goal"],
        output["user_stories"],
        output["functional_requirements"],
        output["non_functional_requirements"],
        output["acceptance_criteria"],
        output["out_of_scope"],
        output["open_questions"],
        output["risks"]
      ].flatten.compact.join("\n")
    end

    def score_terms(category, key, target_text, label)
      terms = Array(expectations[key])
      return RUBRIC.fetch(category) if terms.empty?

      hits = terms.count { |term| target_text.include?(term) }
      add_finding(label, terms, hits)
      RUBRIC.fetch(category) * hits.fdiv(terms.size)
    end

    def score_structure
      required_fields = %w[
        background goal user_stories functional_requirements non_functional_requirements
        acceptance_criteria out_of_scope open_questions risks generated_by_model
      ]
      present = required_fields.count { |field| present_value?(output[field]) }
      presence_score = 6 * present.fdiv(required_fields.size)

      min_counts = expectations.fetch("min_counts", {})
      count_hits = min_counts.count do |field, minimum|
        Array(output[field]).size >= minimum.to_i
      end
      count_score = min_counts.empty? ? 4 : 4 * count_hits.fdiv(min_counts.size)
      findings << "構造: 必須項目 #{present}/#{required_fields.size}、最小件数 #{count_hits}/#{min_counts.size}"

      presence_score + count_score
    end

    def score_traceability
      score = 0
      score += 4 if output["background"].to_s.include?("議事録")
      score += 4 if text_blob.include?("Minutes") || text_blob.include?("議事録")
      source_terms = Array(expectations["source_terms"])
      hits = source_terms.count { |term| text_blob.include?(term) }
      score += source_terms.empty? ? 4 : 4 * hits.fdiv(source_terms.size)
      findings << "根拠追跡性: source term #{hits}/#{source_terms.size}"
      score
    end

    def score_acceptance
      criteria = Array(output["acceptance_criteria"])
      count_score = criteria.size >= expectations.dig("min_counts", "acceptance_criteria").to_i ? 4 : 2
      testable_hits = criteria.count { |item| item.match?(/とき|場合|できる|保存|確認|表示|生成|承認|検証/) }
      testable_score = criteria.empty? ? 0 : 4 * testable_hits.fdiv(criteria.size)
      term_score = score_terms(:acceptance, "acceptance_terms", criteria.join("\n"), "受け入れ条件の期待語") * 4.fdiv(RUBRIC.fetch(:acceptance))
      findings << "受け入れ条件: 検証可能表現 #{testable_hits}/#{criteria.size}"
      count_score + testable_score + term_score
    end

    def score_readiness
      functional_requirements = Array(output["functional_requirements"])
      fr_prefix_hits = functional_requirements.count { |item| item.match?(/\AFR-\d{3}:/) }
      fr_score = functional_requirements.empty? ? 0 : 5 * fr_prefix_hits.fdiv(functional_requirements.size)
      acceptance_score = present_value?(output["acceptance_criteria"]) ? 3 : 0
      openapi_score = text_blob.match?(/OpenAPI|Issue/) ? 2 : 0
      findings << "Issue/OpenAPI readiness: FR形式 #{fr_prefix_hits}/#{functional_requirements.size}"
      fr_score + acceptance_score + openapi_score
    end

    def score_readability
      items = %w[user_stories functional_requirements non_functional_requirements acceptance_criteria out_of_scope open_questions risks].flat_map do |field|
        Array(output[field]).map(&:to_s)
      end
      return 0 if items.empty?

      short_items = items.count { |item| item.length <= 180 }
      duplicates = items.size - items.uniq.size
      score = 5 * short_items.fdiv(items.size)
      score -= [duplicates, 3].min
      findings << "レビュー容易性: 180文字以内 #{short_items}/#{items.size}、重複 #{duplicates}"
      [score, 0].max
    end

    def score_generated_by_model
      output["generated_by_model"].to_s.strip.empty? ? 0 : RUBRIC.fetch(:generated_by_model)
    end

    def detect_forbidden_patterns
      Array(expectations["forbidden_patterns"]).each do |pattern|
        next unless text_blob.match?(Regexp.new(pattern))

        critical_failures << "禁止patternに一致: #{pattern}"
      end
    end

    def present_value?(value)
      case value
      when Array
        value.any? { |item| item.to_s.strip != "" }
      else
        value.to_s.strip != ""
      end
    end

    def add_finding(label, terms, hits)
      findings << "#{label}: #{hits}/#{terms.size}"
    end
  end

  class Reporter
    def initialize(fixtures:, results:, provider_name:, generated_at:)
      @fixtures = fixtures
      @results = results
      @provider_name = provider_name
      @generated_at = generated_at
    end

    def summary
      average = results.map(&:score).sum.fdiv(results.size).round(1)
      thresholds = fixtures.fetch("thresholds")
      p0_categories = thresholds.fetch("p0_categories").map(&:to_sym)
      p0_min_ratio = thresholds.fetch("p0_ratio").to_f
      failed_cases = results.select { |result| result.score < thresholds.fetch("case_score").to_f }
      p0_failures = results.flat_map do |result|
        p0_categories.filter_map do |category|
          max = RUBRIC.fetch(category)
          score = result.category_scores.fetch(category)
          next if score >= max * p0_min_ratio

          "#{result.case_id}: #{P0_CATEGORY_LABELS.fetch(category, category)} #{score}/#{max}"
        end
      end
      critical_failures = results.flat_map(&:critical_failures)

      {
        average: average,
        passed: average >= thresholds.fetch("average_score").to_f &&
          failed_cases.empty? &&
          p0_failures.empty? &&
          critical_failures.empty?,
        failed_cases: failed_cases.map(&:case_id),
        p0_failures: p0_failures,
        critical_failures: critical_failures
      }
    end

    def markdown
      data = summary
      lines = [
        "# Requirement生成品質 baseline",
        "",
        "## メタデータ",
        "",
        "- 生成日時: #{generated_at}",
        "- Issue番号: #{fixtures.fetch("issue")}",
        "- Fixture version: #{fixtures.fetch("version")}",
        "- Provider: #{provider_name}",
        "- 判定: #{data.fetch(:passed) ? "合格" : "基準未達"}",
        "- 平均点: #{data.fetch(:average)} / 100",
        "",
        "## ケース別スコア",
        "",
        "| Case | タイトル | Score | Critical failures |",
        "| --- | --- | ---: | --- |"
      ]

      results.each do |result|
        lines << "| #{result.case_id} | #{result.title} | #{format("%.1f", result.score)} | #{result.critical_failures.empty? ? "なし" : result.critical_failures.join("<br>")} |"
      end

      lines += [
        "",
        "## P0基準未達",
        ""
      ]
      lines += data.fetch(:p0_failures).empty? ? ["- なし"] : data.fetch(:p0_failures).map { |failure| "- #{failure}" }

      lines += [
        "",
        "## 詳細",
        ""
      ]

      results.each do |result|
        lines += [
          "### #{result.case_id}: #{result.title}",
          "",
          "Score: #{format("%.1f", result.score)}",
          "",
          "| Category | Score | Max |",
          "| --- | ---: | ---: |"
        ]
        result.category_scores.each do |category, score|
          lines << "| #{category} | #{format("%.1f", score)} | #{RUBRIC.fetch(category)} |"
        end
        lines += [
          "",
          "Findings:",
          ""
        ]
        lines += result.findings.map { |finding| "- #{finding}" }
        lines << ""
      end

      lines.join("\n")
    end

    private

    attr_reader :fixtures, :results, :provider_name, :generated_at
  end

  class Cli
    def self.run(argv)
      options = {
        fixture_path: DEFAULT_FIXTURE_PATH,
        provider: DEFAULT_PROVIDER,
        output_path: nil,
        enforce: false,
        quiet: false
      }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: ruby scripts/evaluate-requirement-generation.rb [options]"
        opts.on("--fixtures PATH", "評価fixture JSON") { |value| options[:fixture_path] = value }
        opts.on("--provider NAME", "provider名。現在はdeterministicのみ") { |value| options[:provider] = value }
        opts.on("--output PATH", "Markdown baseline reportを書き出す") { |value| options[:output_path] = value }
        opts.on("--enforce", "基準未達ならexit 1") { options[:enforce] = true }
        opts.on("--quiet", "標準出力はsummaryだけにする") { options[:quiet] = true }
      end
      parser.parse!(argv)

      fixtures = JSON.parse(File.read(File.expand_path(options.fetch(:fixture_path), ROOT)))
      provider = build_provider(options.fetch(:provider))
      results = Evaluator.new(fixtures: fixtures, provider: provider).call
      reporter = Reporter.new(
        fixtures: fixtures,
        results: results,
        provider_name: options.fetch(:provider),
        generated_at: Time.now.utc.iso8601
      )
      report = reporter.markdown
      File.write(File.expand_path(options.fetch(:output_path), ROOT), "#{report}\n") if options[:output_path]
      puts options[:quiet] ? summary_line(reporter.summary, results.size) : report

      reporter.summary.fetch(:passed) || !options[:enforce] ? 0 : 1
    end

    def self.summary_line(summary, case_count)
      failed_cases = summary.fetch(:failed_cases).join(",")
      [
        "Requirement generation baseline: #{summary.fetch(:passed) ? "合格" : "基準未達"}",
        "average=#{summary.fetch(:average)}",
        "cases=#{case_count}",
        "failed_cases=#{failed_cases.empty? ? "なし" : failed_cases}",
        "p0_failures=#{summary.fetch(:p0_failures).size}",
        "critical_failures=#{summary.fetch(:critical_failures).size}"
      ].join(" ")
    end

    def self.build_provider(name)
      case name
      when "deterministic"
        require "active_support/core_ext/object/blank"
        require File.join(ROOT, "backend/app/services/requirement_generation/deterministic_provider")
        RequirementGeneration::DeterministicProvider.new
      else
        raise ArgumentError, "unsupported provider: #{name}"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit RequirementGenerationQuality::Cli.run(ARGV)
end
