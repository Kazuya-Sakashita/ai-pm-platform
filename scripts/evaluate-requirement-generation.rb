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
    def initialize(fixtures:, provider:, cases: nil, delay_seconds: 0, sleeper: Kernel)
      @fixtures = fixtures
      @provider = provider
      @cases = cases || fixtures.fetch("cases")
      @delay_seconds = delay_seconds.to_f
      @sleeper = sleeper
    end

    def call
      cases.each_with_index.map do |test_case, index|
        sleeper.sleep(delay_seconds) if index.positive? && delay_seconds.positive?
        output = provider.generate(minutes_from(test_case.fetch("minutes")))
        result = CaseEvaluator.new(test_case: test_case, output: output).call
        yield result if block_given?
        result
      end
    end

    private

    attr_reader :fixtures, :provider, :cases, :delay_seconds, :sleeper

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
        "# Requirement生成品質ベースライン",
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
        "| ケース | タイトル | 点数 | Critical failure |",
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
          "点数: #{format("%.1f", result.score)}",
          "",
          "| 評価カテゴリ | 点数 | 満点 |",
          "| --- | ---: | ---: |"
        ]
        result.category_scores.each do |category, score|
          lines << "| #{category} | #{format("%.1f", score)} | #{RUBRIC.fetch(category)} |"
        end
        lines += [
          "",
          "検出結果:",
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

  class FailureReporter
    def initialize(fixtures:, provider_name:, generated_at:, error:, selected_cases:, completed_results:)
      @fixtures = fixtures
      @provider_name = provider_name
      @generated_at = generated_at
      @error = error
      @selected_cases = selected_cases
      @completed_results = completed_results
    end

    def markdown
      lines = [
        "# Requirement生成評価 safe failure report",
        "",
        "## メタデータ",
        "",
        "- 生成日時: #{generated_at}",
        "- Issue番号: #{fixtures.fetch("issue")}",
        "- Fixture version: #{fixtures.fetch("version")}",
        "- Provider: #{provider_name}",
        "- 判定: 基準未判定",
        "- 選択ケース数: #{selected_cases.size}",
        "- 完了ケース数: #{completed_results.size}",
        "",
        "## Safe failure",
        "",
        "- error_class: #{safe_error_class}",
        "- error_code: #{safe_error_code}",
        "- http_status: #{safe_http_status}",
        "- safe_detail: #{safe_detail}",
        "- request_id_present: #{request_id_present?}",
        "- next_case_id: #{next_case_id || "なし"}",
        "",
        "## 完了済みケース",
        ""
      ]
      lines += completed_case_lines
      lines += [
        "",
        "## 次アクション",
        ""
      ]
      lines += next_actions.map { |action| "- #{action}" }
      lines += [
        "",
        "## 保存していない情報",
        "",
        "- API key",
        "- Authorization header",
        "- raw provider response",
        "- request payload全文",
        "- model output",
        "- PII / credential / token"
      ]
      lines.join("\n")
    end

    def resume_manifest
      {
        generated_at: generated_at,
        fixture_issue: fixtures.fetch("issue", "unknown"),
        fixture_version: fixtures.fetch("version", "unknown"),
        provider: provider_name,
        status: "safe_failure",
        selected_case_ids: selected_cases.map { |test_case| test_case.fetch("id", nil) }.compact,
        completed_case_ids: completed_results.map(&:case_id),
        next_case_id: next_case_id,
        safe_failure: {
          error_class: safe_error_class,
          error_code: safe_error_code,
          http_status: safe_http_status,
          safe_detail: safe_detail,
          request_id_present: request_id_present?
        },
        recommended_cli_args: recommended_cli_args
      }
    end

    private

    attr_reader :fixtures, :provider_name, :generated_at, :error, :selected_cases, :completed_results

    def completed_case_lines
      return ["- なし"] if completed_results.empty?

      completed_results.map do |result|
        "- #{result.case_id}: #{result.title} / #{format("%.1f", result.score)}"
      end
    end

    def safe_error_class
      error.class.name
    end

    def safe_error_code
      return error.code if error.respond_to?(:code) && error.code.to_s.strip != ""

      "evaluation_provider_error"
    end

    def safe_http_status
      return error.http_status if error.respond_to?(:http_status) && error.http_status

      "unknown"
    end

    def safe_detail
      return error.safe_detail if error.respond_to?(:safe_detail) && error.safe_detail.to_s.strip != ""

      "Requirement generation evaluation stopped before completion."
    end

    def request_id_present?
      error.respond_to?(:request_id) && error.request_id.to_s.strip != ""
    end

    def next_case_id
      selected_cases[completed_results.size]&.fetch("id", nil)
    end

    def next_actions
      actions = []
      if safe_http_status.to_s == "too_many_requests" || safe_error_code.to_s.match?(/rate|quota|limit/i)
        actions << "OpenAI Platform側のusage、billing、rate limit、model accessを確認する。"
        actions << "時間を置いてから `--case-id #{next_case_id}` または `--limit 1` で低負荷に再実行する。" if next_case_id
        actions << "`--delay-seconds` を指定してcase間隔を空ける。"
      else
        actions << "safe_detailを確認し、secret値やraw responseを保存せずに原因を切り分ける。"
        actions << "必要に応じて対象caseを `--case-id #{next_case_id}` で再実行する。" if next_case_id
      end
      actions << "成功後に通常の評価Markdownとreview docを保存する。"
      actions.uniq
    end

    def recommended_cli_args
      args = ["--provider", provider_name]
      args += ["--case-id", next_case_id] if next_case_id
      args += ["--delay-seconds", "10"] if safe_http_status.to_s == "too_many_requests" || safe_error_code.to_s.match?(/rate|quota|limit/i)
      args += ["--enforce", "--quiet"]
      args
    end
  end

  class Cli
    def self.run(argv)
      options = {
        fixture_path: DEFAULT_FIXTURE_PATH,
        provider: DEFAULT_PROVIDER,
        output_path: nil,
        failure_output_path: nil,
        resume_output_path: nil,
        case_ids: [],
        limit: nil,
        delay_seconds: 0,
        enforce: false,
        quiet: false
      }
      parser = OptionParser.new do |opts|
        opts.banner = "使い方: ruby scripts/evaluate-requirement-generation.rb [options]"
        opts.on("--fixtures PATH", "評価fixture JSON") { |value| options[:fixture_path] = value }
        opts.on("--provider NAME", "provider名。deterministicまたはopenai") { |value| options[:provider] = value }
        opts.on("--output PATH", "Markdown baseline reportを書き出す") { |value| options[:output_path] = value }
        opts.on("--failure-output PATH", "Provider失敗時のsafe Markdown reportを書き出す") { |value| options[:failure_output_path] = value }
        opts.on("--resume-output PATH", "Provider失敗時のsafe resume JSONを書き出す") { |value| options[:resume_output_path] = value }
        opts.on("--case-id ID", "指定caseだけ評価する。複数指定可") { |value| options[:case_ids] << value }
        opts.on("--limit N", Integer, "先頭N件だけ評価する") { |value| options[:limit] = [value, 1].max }
        opts.on("--delay-seconds N", Float, "case間の待機秒数") { |value| options[:delay_seconds] = [value, 0].max }
        opts.on("--enforce", "基準未達ならexit 1") { options[:enforce] = true }
        opts.on("--quiet", "標準出力はsummaryだけにする") { options[:quiet] = true }
      end
      parser.parse!(argv)

      fixtures = JSON.parse(File.read(File.expand_path(options.fetch(:fixture_path), ROOT)))
      selected_cases = select_cases(
        fixtures.fetch("cases"),
        case_ids: options.fetch(:case_ids),
        limit: options.fetch(:limit)
      )
      provider = build_provider(options.fetch(:provider))
      completed_results = []
      results = Evaluator.new(
        fixtures: fixtures,
        provider: provider,
        cases: selected_cases,
        delay_seconds: options.fetch(:delay_seconds),
        sleeper: Kernel
      ).call do |result|
        completed_results << result
      end
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
    rescue OptionParser::ParseError => e
      warn "引数が不正です: #{e.message}"
      2
    rescue StandardError => e
      failure_report = FailureReporter.new(
        fixtures: fixtures || { "issue" => "unknown", "version" => "unknown" },
        provider_name: options.fetch(:provider),
        generated_at: Time.now.utc.iso8601,
        error: e,
        selected_cases: selected_cases || [],
        completed_results: completed_results || []
      )
      if options[:failure_output_path]
        File.write(File.expand_path(options.fetch(:failure_output_path), ROOT), "#{failure_report.markdown}\n")
      end
      if options[:resume_output_path]
        File.write(File.expand_path(options.fetch(:resume_output_path), ROOT), "#{JSON.pretty_generate(failure_report.resume_manifest)}\n")
      end
      warn "Requirement生成品質評価: safe failure #{failure_report.send(:safe_error_code)}"
      warn "safe_detail: #{failure_report.send(:safe_detail)}"
      1
    end

    def self.summary_line(summary, case_count)
      failed_cases = summary.fetch(:failed_cases).join(",")
      [
        "Requirement生成品質ベースライン: #{summary.fetch(:passed) ? "合格" : "基準未達"}",
        "平均点=#{summary.fetch(:average)}",
        "ケース数=#{case_count}",
        "基準未達ケース=#{failed_cases.empty? ? "なし" : failed_cases}",
        "P0未達=#{summary.fetch(:p0_failures).size}",
        "Critical failure=#{summary.fetch(:critical_failures).size}"
      ].join(" ")
    end

    def self.select_cases(cases, case_ids:, limit:)
      selected = if case_ids.empty?
                   cases
                 else
                   case_ids.flat_map do |case_id|
                     match = cases.find { |test_case| test_case.fetch("id") == case_id }
                     raise ArgumentError, "未対応のcase-idです: #{case_id}" unless match

                     match
                   end
                 end
      limit ? selected.first(limit) : selected
    end

    def self.build_provider(name)
      case name
      when "deterministic"
        require "active_support/core_ext/object/blank"
        require File.join(ROOT, "backend/app/services/requirement_generation/deterministic_provider")
        RequirementGeneration::DeterministicProvider.new
      when "openai"
        require "active_support/core_ext/object/blank"
        require "active_support/core_ext/string/filters"
        require File.join(ROOT, "backend/app/services/requirement_generation/provider_error")
        require File.join(ROOT, "backend/app/services/requirement_generation/openai_provider")
        RequirementGeneration::OpenaiProvider.new
      else
        raise ArgumentError, "未対応のproviderです: #{name}"
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit RequirementGenerationQuality::Cli.run(ARGV)
end
