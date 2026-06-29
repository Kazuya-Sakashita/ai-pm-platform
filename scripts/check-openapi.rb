#!/usr/bin/env ruby
# frozen_string_literal: true

require "yaml"

path = ARGV.fetch(0, "docs/api/openapi.yaml")
doc = YAML.load_file(path)

components = doc.fetch("components", {})
schemas = components.fetch("schemas", {})
parameters = components.fetch("parameters", {})
responses = components.fetch("responses", {})

sources = {
  "schemas" => schemas,
  "parameters" => parameters,
  "responses" => responses
}

missing = []

walk = lambda do |value|
  case value
  when Hash
    ref = value["$ref"]
    if ref&.start_with?("#/components/")
      parts = ref.split("/")
      type = parts[-2]
      name = parts[-1]
      source = sources[type]
      missing << ref if source && !source.key?(name)
    end

    value.each_value { |child| walk.call(child) }
  when Array
    value.each { |child| walk.call(child) }
  end
end

walk.call(doc)

if missing.any?
  warn "Missing OpenAPI refs:"
  missing.uniq.sort.each { |ref| warn "- #{ref}" }
  exit 1
end

puts "OpenAPI OK: #{path}"

