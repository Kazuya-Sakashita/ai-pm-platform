require "base64"
require "json"
require "openssl"

module Authentication
  class JwtVerifier
    DEFAULT_ISSUER = "ai-pm-platform".freeze
    DEFAULT_AUDIENCE = "ai-pm-platform-api".freeze
    DEFAULT_CLOCK_SKEW_SECONDS = 30
    DEVELOPMENT_SECRET = "local-dev-auth-secret".freeze

    Result = Struct.new(:actor_id, :claims, keyword_init: true)

    class Error < StandardError
      attr_reader :code, :safe_detail, :http_status

      def initialize(code:, safe_detail:, http_status: :unauthorized)
        super(safe_detail)
        @code = code
        @safe_detail = safe_detail
        @http_status = http_status
      end
    end

    def initialize(
      secret: self.class.secret,
      issuer: ENV.fetch("AUTH_JWT_ISSUER", DEFAULT_ISSUER),
      audience: ENV.fetch("AUTH_JWT_AUDIENCE", DEFAULT_AUDIENCE),
      clock_skew_seconds: ENV.fetch("AUTH_JWT_CLOCK_SKEW_SECONDS", DEFAULT_CLOCK_SKEW_SECONDS).to_i
    )
      @secret = secret
      @issuer = issuer
      @audience = audience
      @clock_skew_seconds = clock_skew_seconds
    end

    def self.secret
      ENV["AUTH_JWT_SECRET"].presence || (Rails.env.production? ? nil : DEVELOPMENT_SECRET)
    end

    def verify!(token, now: Time.current)
      raise_error("invalid_token", "Authentication token is invalid.") if token.blank?
      raise_error("authentication_not_configured", "Authentication is not configured.", :service_unavailable) if secret.blank?

      header_segment, payload_segment, signature_segment = token.to_s.split(".", 3)
      raise_error("invalid_token", "Authentication token is invalid.") if [header_segment, payload_segment, signature_segment].any?(&:blank?)

      header = decode_json(header_segment)
      payload = decode_json(payload_segment)

      validate_header!(header)
      validate_signature!(header_segment, payload_segment, signature_segment)
      validate_claims!(payload, now)

      Result.new(actor_id: payload.fetch("sub"), claims: payload)
    end

    private

    attr_reader :secret, :issuer, :audience, :clock_skew_seconds

    def validate_header!(header)
      raise_error("invalid_token", "Authentication token is invalid.") unless header["alg"] == "HS256"
      raise_error("invalid_token", "Authentication token is invalid.") if header["typ"].present? && header["typ"] != "JWT"
    end

    def validate_signature!(header_segment, payload_segment, signature_segment)
      signing_input = [header_segment, payload_segment].join(".")
      expected = OpenSSL::HMAC.digest("SHA256", secret, signing_input)
      actual = decode_segment(signature_segment)

      valid = actual.bytesize == expected.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(actual, expected)
      raise_error("invalid_token", "Authentication token is invalid.") unless valid
    end

    def validate_claims!(payload, now)
      actor_id = payload["sub"].to_s
      raise_error("invalid_token", "Authentication token is invalid.") if actor_id.blank? || actor_id.length > 120
      raise_error("invalid_token", "Authentication token is invalid.") unless payload["iss"] == issuer
      raise_error("invalid_token", "Authentication token is invalid.") unless audience_matches?(payload["aud"])

      exp = integer_claim(payload, "exp")
      raise_error("invalid_token", "Authentication token is invalid.") unless exp
      raise_error("token_expired", "Authentication token has expired.") if Time.at(exp) < now - clock_skew_seconds

      nbf = integer_claim(payload, "nbf")
      raise_error("token_not_yet_valid", "Authentication token is not active yet.") if nbf && Time.at(nbf) > now + clock_skew_seconds

      iat = integer_claim(payload, "iat")
      raise_error("invalid_token", "Authentication token is invalid.") if iat && Time.at(iat) > now + clock_skew_seconds
    end

    def audience_matches?(claim)
      Array(claim).include?(audience)
    end

    def integer_claim(payload, key)
      return nil unless payload.key?(key)

      Integer(payload[key])
    rescue ArgumentError, TypeError
      nil
    end

    def decode_json(segment)
      JSON.parse(decode_segment(segment))
    rescue JSON::ParserError
      raise_error("invalid_token", "Authentication token is invalid.")
    end

    def decode_segment(segment)
      padded = segment.to_s + ("=" * ((4 - segment.to_s.length % 4) % 4))
      Base64.urlsafe_decode64(padded)
    rescue ArgumentError
      raise_error("invalid_token", "Authentication token is invalid.")
    end

    def raise_error(code, safe_detail, http_status = :unauthorized)
      raise Error.new(code: code, safe_detail: safe_detail, http_status: http_status)
    end
  end
end
