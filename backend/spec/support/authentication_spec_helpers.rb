require "base64"
require "json"
require "openssl"

module AuthenticationSpecHelpers
  def auth_headers(actor_id = "dm-editor", **options)
    { "Authorization" => "Bearer #{jwt_token(actor_id: actor_id, **options)}" }
  end

  def legacy_actor_headers(actor_id = "dm-editor")
    { "X-Actor-Id" => actor_id }
  end

  def jwt_token(
    actor_id: "dm-editor",
    secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET,
    issuer: Authentication::JwtVerifier::DEFAULT_ISSUER,
    audience: Authentication::JwtVerifier::DEFAULT_AUDIENCE,
    expires_at: 1.hour.from_now,
    issued_at: Time.current,
    not_before: nil,
    algorithm: "HS256",
    extra_claims: {}
  )
    header = { alg: algorithm, typ: "JWT" }
    payload = {
      sub: actor_id,
      iss: issuer,
      aud: audience,
      exp: expires_at.to_i,
      iat: issued_at.to_i
    }.merge(extra_claims)
    payload[:nbf] = not_before.to_i if not_before

    signing_input = [base64_json(header), base64_json(payload)].join(".")
    return "#{signing_input}." if algorithm == "none"

    signature = OpenSSL::HMAC.digest("SHA256", secret, signing_input)
    [signing_input, base64_url(signature)].join(".")
  end

  def with_env(values)
    originals = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  private

  def base64_json(value)
    base64_url(JSON.generate(value))
  end

  def base64_url(value)
    Base64.urlsafe_encode64(value).delete("=")
  end
end
