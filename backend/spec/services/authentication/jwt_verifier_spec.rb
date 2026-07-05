require "rails_helper"

RSpec.describe Authentication::JwtVerifier do
  it "returns the actor id from a valid token" do
    token = jwt_token(actor_id: "dm-editor")

    result = described_class.new.verify!(token)

    expect(result.actor_id).to eq("dm-editor")
    expect(result.claims).to include("sub" => "dm-editor")
  end

  it "rejects malformed tokens with a safe error" do
    expect { described_class.new.verify!("not-a-jwt") }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("invalid_token")
        expect(error.safe_detail).to eq("Authentication token is invalid.")
      }
  end

  it "rejects expired tokens" do
    token = jwt_token(expires_at: 1.hour.ago)

    expect { described_class.new.verify!(token) }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("token_expired")
      }
  end

  it "rejects tokens signed with the wrong secret" do
    token = jwt_token(secret: "wrong-secret")

    expect { described_class.new.verify!(token) }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("invalid_token")
      }
  end

  it "rejects unexpected algorithms" do
    token = jwt_token(algorithm: "none")

    expect { described_class.new.verify!(token) }
      .to raise_error(Authentication::JwtVerifier::Error) { |error|
        expect(error.code).to eq("invalid_token")
      }
  end
end
