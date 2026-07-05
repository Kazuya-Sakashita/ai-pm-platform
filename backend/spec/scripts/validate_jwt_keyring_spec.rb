require "spec_helper"
require "stringio"

require_relative "../../../scripts/validate-jwt-keyring"

RSpec.describe JwtKeyringReleaseGate::Validator do
  let(:now) { Time.iso8601("2026-07-06T00:00:00Z") }

  def keyring(keys)
    JSON.generate(keys: keys)
  end

  def validate(raw, environment: "staging", mode: "rotation")
    described_class.new(
      raw: raw,
      environment: environment,
      mode: mode,
      now: now,
      require_secret_env: %w[staging production].include?(environment),
      check_secret_presence: %w[staging production].include?(environment)
    ).call
  end

  def with_env(values)
    originals = values.keys.to_h { |key| [key, ENV[key]] }
    values.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    originals.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  it "accepts a staging rotation keyring without exposing secret values" do
    raw = keyring([
      {
        kid: "jwt-2026-07-a",
        secret_env: "JWT_OLD_SECRET",
        status: "verify_only",
        retire_after: "2026-07-06T01:00:00Z"
      },
      {
        kid: "jwt-2026-07-b",
        secret_env: "JWT_NEW_SECRET",
        status: "active",
        not_before: "2026-07-06T00:00:00Z"
      }
    ])

    with_env("JWT_OLD_SECRET" => "old-secret-value", "JWT_NEW_SECRET" => "new-secret-value", "AUTH_JWT_KEYRING_JSON" => raw) do
      stdout = StringIO.new
      stderr = StringIO.new
      original_stdout = $stdout
      original_stderr = $stderr
      $stdout = stdout
      $stderr = stderr

      status = JwtKeyringReleaseGate::Cli.run([
        "--environment", "staging",
        "--mode", "rotation",
        "--now", "2026-07-06T00:00:00Z"
      ])

      expect(status).to eq(0)
      expect(stdout.string).to include("active_kid=jwt-2026-07-b")
      expect(stdout.string).not_to include("old-secret-value", "new-secret-value")
      expect(stderr.string).not_to include("old-secret-value", "new-secret-value")
    ensure
      $stdout = original_stdout
      $stderr = original_stderr
    end

    with_env("JWT_OLD_SECRET" => "old-secret-value", "JWT_NEW_SECRET" => "new-secret-value", "AUTH_JWT_KEYRING_JSON" => raw) do
      result = validate(raw)

      expect(result.active_kid).to eq("jwt-2026-07-b")
      expect(result.verify_capable_kids).to contain_exactly("jwt-2026-07-a", "jwt-2026-07-b")
    end
  end

  it "rejects inline secret material in production-like environments" do
    raw = keyring([
      { kid: "jwt-inline-a", secret: "never-commit-this", status: "active" },
      { kid: "jwt-inline-b", secret_env: "JWT_VERIFY_SECRET", status: "verify_only", retire_after: "2026-07-06T01:00:00Z" }
    ])

    with_env("JWT_VERIFY_SECRET" => "verify-secret") do
      expect { validate(raw, environment: "production") }
        .to raise_error(JwtKeyringReleaseGate::ValidationError) { |error|
          expect(error.errors.join("\n")).to include("must not contain inline secret material")
          expect(error.errors.join("\n")).not_to include("never-commit-this")
        }
    end
  end

  it "rejects duplicate kid values" do
    raw = keyring([
      { kid: "jwt-dup", secret_env: "JWT_A_SECRET", status: "active" },
      { kid: "jwt-dup", secret_env: "JWT_B_SECRET", status: "verify_only", retire_after: "2026-07-06T01:00:00Z" }
    ])

    with_env("JWT_A_SECRET" => "a-secret", "JWT_B_SECRET" => "b-secret") do
      expect { validate(raw) }
        .to raise_error(JwtKeyringReleaseGate::ValidationError) { |error|
          expect(error.errors).to include('duplicate kid "jwt-dup"')
        }
    end
  end

  it "requires a retirement window for verify-only keys during rotation" do
    raw = keyring([
      { kid: "jwt-old", secret_env: "JWT_OLD_SECRET", status: "verify_only" },
      { kid: "jwt-new", secret_env: "JWT_NEW_SECRET", status: "active" }
    ])

    with_env("JWT_OLD_SECRET" => "old-secret", "JWT_NEW_SECRET" => "new-secret") do
      expect { validate(raw) }
        .to raise_error(JwtKeyringReleaseGate::ValidationError) { |error|
          expect(error.errors.join("\n")).to include("retire_after is missing")
        }
    end
  end

  it "allows retired and disabled keys without secret material" do
    raw = keyring([
      { kid: "jwt-current", secret_env: "JWT_CURRENT_SECRET", status: "active" },
      { kid: "jwt-retired", status: "retired" },
      { kid: "jwt-disabled", status: "disabled" }
    ])

    with_env("JWT_CURRENT_SECRET" => "current-secret") do
      result = validate(raw, mode: "steady")

      expect(result.active_kid).to eq("jwt-current")
      expect(result.retired_kids).to contain_exactly("jwt-retired")
      expect(result.disabled_kids).to contain_exactly("jwt-disabled")
    end
  end
end
