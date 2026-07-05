#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "optparse"
require "time"

module JwtKeyringReleaseGate
  VALID_ALGORITHMS = %w[HS256].freeze
  VALID_STATUSES = %w[active verify_only retired disabled].freeze
  PRODUCTION_LIKE_ENVIRONMENTS = %w[staging production].freeze
  VERIFY_CAPABLE_STATUSES = %w[active verify_only].freeze
  KID_PATTERN = /\A[A-Za-z0-9][A-Za-z0-9._:-]{2,79}\z/

  Result = Struct.new(:active_kid, :verify_capable_kids, :retired_kids, :disabled_kids, :warnings, keyword_init: true)

  class ValidationError < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(errors.join("; "))
    end
  end

  class Validator
    def initialize(raw:, environment:, mode:, now:, require_secret_env:, check_secret_presence:)
      @raw = raw
      @environment = environment
      @mode = mode
      @now = now
      @require_secret_env = require_secret_env
      @check_secret_presence = check_secret_presence
    end

    def call
      errors = []
      warnings = []
      parsed = parse_json(errors)
      keys = extract_keys(parsed, errors)
      summaries = summarize_keys(keys, errors, warnings)

      active_keys = summaries.select { |key| key[:status] == "active" && key[:currently_usable] }
      verify_capable_keys = summaries.select { |key| VERIFY_CAPABLE_STATUSES.include?(key[:status]) && key[:currently_usable] }
      retired_kids = summaries.select { |key| key[:status] == "retired" }.map { |key| key[:kid] }
      disabled_kids = summaries.select { |key| key[:status] == "disabled" }.map { |key| key[:kid] }

      errors << "keyring must contain exactly one currently usable active key; found #{active_keys.size}" unless active_keys.size == 1
      errors << "keyring must contain at least one currently usable verification key" if verify_capable_keys.empty?

      if mode == "rotation" && verify_capable_keys.size < 2
        errors << "rotation mode requires at least two currently usable verification keys"
      end

      raise ValidationError, errors if errors.any?

      Result.new(
        active_kid: active_keys.first.fetch(:kid),
        verify_capable_kids: verify_capable_keys.map { |key| key.fetch(:kid) },
        retired_kids: retired_kids,
        disabled_kids: disabled_kids,
        warnings: warnings
      )
    end

    private

    attr_reader :raw, :environment, :mode, :now, :require_secret_env, :check_secret_presence

    def parse_json(errors)
      errors << "AUTH_JWT_KEYRING_JSON or --file is required" if blank?(raw)
      return nil if errors.any?

      JSON.parse(raw)
    rescue JSON::ParserError => e
      errors << "keyring JSON is invalid: #{e.message}"
      nil
    end

    def extract_keys(parsed, errors)
      return [] unless parsed

      keys = parsed.is_a?(Hash) ? parsed["keys"] : parsed
      unless keys.is_a?(Array)
        errors << "keyring must be an array or an object with a keys array"
        return []
      end

      errors << "keyring must contain at least one key" if keys.empty?
      keys
    end

    def summarize_keys(keys, errors, warnings)
      seen_kids = {}

      keys.each_with_index.map do |entry, index|
        label = "keys[#{index}]"
        unless entry.is_a?(Hash)
          errors << "#{label} must be an object"
          next invalid_summary(index)
        end

        kid = entry["kid"].to_s.strip
        algorithm = entry.fetch("algorithm", "HS256").to_s
        status = entry.fetch("status", "active").to_s
        secret_env = entry["secret_env"].to_s.strip
        inline_secret = !blank?(entry["secret"])
        not_before = parse_time(entry["not_before"], "#{label}.not_before", errors)
        retire_after = parse_time(entry["retire_after"], "#{label}.retire_after", errors)

        validate_kid(label, kid, seen_kids, errors)
        validate_algorithm(label, algorithm, errors)
        validate_status(label, status, errors)
        validate_secret_reference(label, status, inline_secret, secret_env, errors)
        validate_time_window(label, status, not_before, retire_after, errors, warnings)

        {
          index: index,
          kid: kid,
          algorithm: algorithm,
          status: status,
          not_before: not_before,
          retire_after: retire_after,
          currently_usable: currently_usable?(status, not_before, retire_after)
        }
      end
    end

    def invalid_summary(index)
      {
        index: index,
        kid: "",
        algorithm: "",
        status: "",
        not_before: nil,
        retire_after: nil,
        currently_usable: false
      }
    end

    def validate_kid(label, kid, seen_kids, errors)
      errors << "#{label}.kid is required" if kid.empty?
      errors << "#{label}.kid has invalid characters or length" unless kid.empty? || kid.match?(KID_PATTERN)
      errors << "duplicate kid #{kid.inspect}" if kid != "" && seen_kids[kid]
      seen_kids[kid] = true unless kid.empty?
    end

    def validate_algorithm(label, algorithm, errors)
      errors << "#{label}.algorithm must be one of #{VALID_ALGORITHMS.join(", ")}" unless VALID_ALGORITHMS.include?(algorithm)
    end

    def validate_status(label, status, errors)
      errors << "#{label}.status must be one of #{VALID_STATUSES.join(", ")}" unless VALID_STATUSES.include?(status)
    end

    def validate_secret_reference(label, status, inline_secret, secret_env, errors)
      if production_like? && inline_secret
        errors << "#{label}.secret must not contain inline secret material in #{environment}"
      end

      return unless VERIFY_CAPABLE_STATUSES.include?(status)

      if require_secret_env && secret_env.empty?
        errors << "#{label}.secret_env is required for #{status} keys in #{environment}"
      end

      if check_secret_presence && !secret_env.empty? && blank?(ENV[secret_env])
        errors << "#{label}.secret_env #{secret_env.inspect} is not present in the environment"
      end

      if !require_secret_env && !inline_secret && secret_env.empty?
        errors << "#{label} must reference a secret through secret_env or secret"
      end
    end

    def validate_time_window(label, status, not_before, retire_after, errors, warnings)
      errors << "#{label}.retire_after must be after not_before" if not_before && retire_after && retire_after <= not_before

      if VERIFY_CAPABLE_STATUSES.include?(status) && retire_after && now >= retire_after
        errors << "#{label} is #{status} but retire_after has already passed"
      end

      if status == "active" && not_before && now < not_before
        errors << "#{label} is active but not_before is in the future"
      end

      if mode == "rotation" && status == "verify_only" && retire_after.nil?
        errors << "#{label} is verify_only in rotation mode but retire_after is missing"
      end

      if mode == "steady" && status == "verify_only" && retire_after.nil?
        warnings << "#{label} is verify_only without retire_after; define the retirement window before production rotation"
      end
    end

    def parse_time(value, label, errors)
      return nil if blank?(value)

      Time.iso8601(value.to_s).utc
    rescue ArgumentError
      errors << "#{label} must be ISO8601"
      nil
    end

    def currently_usable?(status, not_before, retire_after)
      return false unless VERIFY_CAPABLE_STATUSES.include?(status)
      return false if not_before && now < not_before
      return false if retire_after && now >= retire_after

      true
    end

    def production_like?
      PRODUCTION_LIKE_ENVIRONMENTS.include?(environment)
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end

  class Cli
    DEFAULT_MODE = "steady"

    def self.run(argv)
      new(argv).run
    end

    def initialize(argv)
      @argv = argv
      @options = {
        environment: ENV["APP_ENV"] || ENV["RAILS_ENV"] || "development",
        mode: DEFAULT_MODE,
        now: Time.now.utc,
        require_secret_env: nil,
        check_secret_presence: nil
      }
    end

    def run
      parser.parse!(argv)
      normalize_options

      raw = options[:file] ? File.read(options[:file]) : ENV["AUTH_JWT_KEYRING_JSON"]
      result = Validator.new(
        raw: raw,
        environment: options.fetch(:environment),
        mode: options.fetch(:mode),
        now: options.fetch(:now),
        require_secret_env: options.fetch(:require_secret_env),
        check_secret_presence: options.fetch(:check_secret_presence)
      ).call

      puts [
        "JWT keyring validation OK:",
        "environment=#{options.fetch(:environment)}",
        "mode=#{options.fetch(:mode)}",
        "active_kid=#{result.active_kid}",
        "verify_capable_kids=#{result.verify_capable_kids.join(",")}",
        "retired_kids=#{result.retired_kids.join(",")}",
        "disabled_kids=#{result.disabled_kids.join(",")}"
      ].join(" ")

      unless result.warnings.empty?
        warn "JWT keyring validation warnings:"
        result.warnings.each { |warning| warn "- #{warning}" }
      end

      0
    rescue ValidationError => e
      warn "JWT keyring validation failed:"
      e.errors.each { |error| warn "- #{error}" }
      1
    rescue Errno::ENOENT => e
      warn "JWT keyring validation failed:"
      warn "- file not found: #{e.message}"
      1
    rescue OptionParser::ParseError, ArgumentError => e
      warn "JWT keyring validation failed:"
      warn "- #{e.message}"
      1
    end

    private

    attr_reader :argv, :options

    def parser
      OptionParser.new do |opts|
        opts.banner = "Usage: validate-jwt-keyring.rb [options]"
        opts.on("--file PATH", "Read keyring JSON from PATH instead of AUTH_JWT_KEYRING_JSON") { |value| options[:file] = value }
        opts.on("--environment NAME", "Environment name, for example staging or production") { |value| options[:environment] = value.to_s }
        opts.on("--mode MODE", "Validation mode: steady or rotation") { |value| options[:mode] = value.to_s }
        opts.on("--now ISO8601", "Fixed current time for deterministic validation") { |value| options[:now] = Time.iso8601(value).utc }
        opts.on("--allow-inline-secret", "Allow inline secret fields. Never use for staging/production.") { options[:require_secret_env] = false }
        opts.on("--skip-secret-presence", "Do not require secret_env variables to exist in ENV") { options[:check_secret_presence] = false }
      end
    end

    def normalize_options
      unless %w[steady rotation].include?(options.fetch(:mode))
        raise ArgumentError, "--mode must be steady or rotation"
      end

      production_like = PRODUCTION_LIKE_ENVIRONMENTS.include?(options.fetch(:environment))
      options[:require_secret_env] = production_like if options[:require_secret_env].nil?
      options[:check_secret_presence] = production_like if options[:check_secret_presence].nil?
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  exit JwtKeyringReleaseGate::Cli.run(ARGV)
end
