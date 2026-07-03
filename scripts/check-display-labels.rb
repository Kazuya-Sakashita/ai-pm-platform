#!/usr/bin/env ruby
# frozen_string_literal: true

ROOT = File.expand_path("..", __dir__)
DISPLAY_LABELS_PATH = File.join(ROOT, "frontend/lib/display-labels.ts")
GLOSSARY_PATH = File.join(ROOT, "docs/product/20260701_japanese_ui_glossary.md")
OPENAPI_PATH = File.join(ROOT, "docs/api/openapi.yaml")
JAPANESE_PATTERN = /[ぁ-んァ-ヶ一-龠々ー]/

def extract_ts_map(source, name)
  block = source[/const #{Regexp.escape(name)}: Record<string, string> = \{\n(.*?)\n\};/m, 1]
  raise "Could not find #{name} in #{DISPLAY_LABELS_PATH}" unless block

  block.lines.each_with_object({}) do |line, labels|
    next unless line.match?(/:\s*"/)

    key, value =
      if (quoted = line.match(/^\s*"(.+?)":\s*"(.+?)"/))
        quoted.captures
      elsif (plain = line.match(/^\s*([a-zA-Z0-9_]+):\s*"(.+?)"/))
        plain.captures
      end

    labels[key] = value if key && value
  end
end

def extract_section_table(markdown, title)
  section = markdown[/## #{Regexp.escape(title)}\n(.*?)(?=\n## |\z)/m, 1]
  raise "Could not find section #{title} in #{GLOSSARY_PATH}" unless section

  section.lines.each_with_object({}) do |line, rows|
    next unless line.start_with?("|")
    next if line.include?("---")

    cells = line.split("|").map(&:strip).reject(&:empty?)
    next if cells.size < 2
    next if cells.first.match?(/内部値|英語|概念/)

    rows[cells[0]] = cells[1]
  end
end

display_source = File.read(DISPLAY_LABELS_PATH)
glossary_source = File.read(GLOSSARY_PATH)
openapi_source = File.read(OPENAPI_PATH)

message_labels = extract_ts_map(display_source, "messageLabels")
status_labels = extract_ts_map(display_source, "statusLabels")
target_labels = extract_ts_map(display_source, "targetLabels")

errors = []

{
  "messageLabels" => message_labels,
  "statusLabels" => status_labels,
  "targetLabels" => target_labels
}.each do |map_name, labels|
  labels.each do |key, value|
    next if value.match?(JAPANESE_PATTERN)

    errors << "#{map_name}.#{key} must contain Japanese display text: #{value.inspect}"
  end
end

glossary_statuses = {}
["共通ステータス", "Reviewステータス", "GitHub公開・照合"].each do |section_title|
  extract_section_table(glossary_source, section_title).each do |key, value|
    next unless key.match?(/\A[a-z][a-z0-9_]*\z/)

    glossary_statuses[key] = value
  end
end

glossary_statuses.each do |key, expected|
  actual = status_labels[key]
  errors << "statusLabels is missing glossary status #{key}" unless actual
  errors << "statusLabels.#{key} should be #{expected.inspect}, got #{actual.inspect}" if actual && actual != expected
end

history_schema = openapi_source[/GitHubReconciliationHistoryItem:\n(.*?)(?=\n    [A-Z][A-Za-z0-9]+:|\n    IssueDraft:)/m, 1]
if history_schema
  history_statuses = history_schema[/enum: \[(.*?)\]/, 1].to_s.split(",").map(&:strip)
  history_statuses.each do |status|
    errors << "statusLabels is missing GitHubReconciliationHistoryItem status #{status}" unless status_labels[status]
  end
else
  errors << "Could not find GitHubReconciliationHistoryItem in #{OPENAPI_PATH}"
end

glossary_targets = extract_section_table(glossary_source, "主要ラベル")
target_expectations = {
  "minutes" => glossary_targets.fetch("Minutes"),
  "requirement" => glossary_targets.fetch("Requirement"),
  "issue_draft" => glossary_targets.fetch("Issue Draft"),
  "openapi_draft" => glossary_targets.fetch("OpenAPI Draft")
}

target_expectations.each do |key, expected|
  actual = target_labels[key]
  errors << "targetLabels is missing glossary target #{key}" unless actual
  errors << "targetLabels.#{key} should be #{expected.inspect}, got #{actual.inspect}" if actual && actual != expected
end

if errors.any?
  warn "Display label consistency check failed:"
  errors.each { |error| warn "- #{error}" }
  exit 1
end

puts "Display labels OK: #{message_labels.size} messages, #{status_labels.size} statuses, #{target_labels.size} targets"
