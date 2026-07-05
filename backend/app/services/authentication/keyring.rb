require "json"

module Authentication
  class Keyring
    STATUSES = %w[active verify_only retired disabled].freeze
    ALGORITHMS = %w[HS256].freeze

    Key = Struct.new(:kid, :secret, :algorithm, :status, :not_before, :retire_after, keyword_init: true)

    def self.from_env(legacy_secret:)
      new(
        keys: keys_from_json(ENV["AUTH_JWT_KEYRING_JSON"]),
        legacy_secret: legacy_secret,
        allow_legacy: ActiveModel::Type::Boolean.new.cast(ENV.fetch("AUTH_JWT_ALLOW_LEGACY_SECRET", "true"))
      )
    end

    def self.keys_from_json(raw)
      return [] if raw.blank?

      parsed = JSON.parse(raw)
      keys = Array(parsed.is_a?(Hash) ? parsed.fetch("keys", []) : parsed).map do |entry|
        Key.new(
          kid: entry.fetch("kid").to_s,
          secret: key_secret(entry),
          algorithm: entry.fetch("algorithm", "HS256").to_s,
          status: entry.fetch("status", "active").to_s,
          not_before: parse_time(entry["not_before"]),
          retire_after: parse_time(entry["retire_after"])
        )
      end
      raise KeyError if keys.map(&:kid).uniq.size != keys.size

      keys
    rescue JSON::ParserError, KeyError
      raise_error("authentication_not_configured", "Authentication is not configured.", :service_unavailable)
    end

    def self.key_secret(entry)
      status = entry.fetch("status", "active").to_s
      if %w[retired disabled].include?(status)
        return entry["secret"].presence || ENV[entry["secret_env"].to_s].presence
      end

      secret = entry["secret"].presence || ENV[entry["secret_env"].to_s].presence
      raise KeyError if secret.blank?

      secret
    end

    def self.parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def initialize(keys:, legacy_secret:, allow_legacy:)
      @keys = keys
      @legacy_secret = legacy_secret
      @allow_legacy = allow_legacy
    end

    def verification_secret_for!(header, now:)
      kid = header["kid"].to_s
      return legacy_secret_for_header!(header) if kid.blank?

      key = keys.find { |candidate| candidate.kid == kid }
      raise_error("signing_key_unknown", "Authentication token key is unknown.") unless key
      raise_error("invalid_token", "Authentication token is invalid.") unless ALGORITHMS.include?(key.algorithm)
      raise_error("invalid_token", "Authentication token is invalid.") unless key.algorithm == header["alg"]
      raise_error("signing_key_retired", "Authentication token key has been retired.") if key.status == "retired" || (key.retire_after && now >= key.retire_after)
      raise_error("signing_key_not_active", "Authentication token key is not active.") if key.status == "disabled" || !STATUSES.include?(key.status)
      raise_error("signing_key_not_active", "Authentication token key is not active.") if key.not_before && now < key.not_before

      key.secret
    end

    private

    attr_reader :keys, :legacy_secret, :allow_legacy

    def legacy_secret_for_header!(header)
      raise_error("signing_key_unknown", "Authentication token key is unknown.") unless allow_legacy && legacy_secret.present?
      raise_error("invalid_token", "Authentication token is invalid.") unless header["alg"] == "HS256"

      legacy_secret
    end

    def self.raise_error(code, safe_detail, http_status = :unauthorized)
      raise Authentication::JwtVerifier::Error.new(code: code, safe_detail: safe_detail, http_status: http_status)
    end

    def raise_error(code, safe_detail, http_status = :unauthorized)
      self.class.raise_error(code, safe_detail, http_status)
    end
  end
end
