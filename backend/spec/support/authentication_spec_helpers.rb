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
    kid: nil,
    sid: nil,
    session_version: nil,
    jti: nil,
    issuer: Authentication::JwtVerifier::DEFAULT_ISSUER,
    audience: Authentication::JwtVerifier::DEFAULT_AUDIENCE,
    expires_at: 10.minutes.from_now,
    issued_at: Time.current,
    not_before: nil,
    algorithm: "HS256",
    header_claims: {},
    extra_claims: {}
  )
    header = { alg: algorithm, typ: "JWT" }.merge(header_claims)
    header[:kid] = kid if kid
    payload = {
      sub: actor_id,
      iss: issuer,
      aud: audience,
      exp: expires_at.to_i,
      iat: issued_at.to_i
    }.merge(extra_claims)
    payload[:nbf] = not_before.to_i if not_before
    payload[:sid] = sid if sid
    payload[:sv] = session_version if session_version
    payload[:jti] = jti if jti

    signing_input = [base64_json(header), base64_json(payload)].join(".")
    return "#{signing_input}." if algorithm == "none"

    signature = OpenSSL::HMAC.digest("SHA256", secret, signing_input)
    [signing_input, base64_url(signature)].join(".")
  end

  def session_auth_headers(actor_id: "dm-editor", kid: "test-active", secret: Authentication::JwtVerifier::DEVELOPMENT_SECRET, jti: "token-1", issued_at: Time.current, expires_at: 10.minutes.from_now)
    auth_actor = AuthActor.find_or_create_by!(subject: actor_id) do |actor|
      actor.status = "active"
      actor.session_version = 1
    end
    auth_session = create(
      :auth_session,
      auth_actor: auth_actor,
      actor_subject: actor_id,
      session_version: auth_actor.session_version,
      issued_at: issued_at,
      expires_at: expires_at
    )
    token = jwt_token(
      actor_id: actor_id,
      secret: secret,
      kid: kid,
      sid: auth_session.sid,
      session_version: auth_actor.session_version,
      jti: jti,
      issued_at: issued_at,
      expires_at: expires_at
    )

    [{ "Authorization" => "Bearer #{token}" }, auth_actor, auth_session, jti]
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
