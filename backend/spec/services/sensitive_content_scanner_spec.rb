require "rails_helper"

RSpec.describe SensitiveContentScanner do
  it "blocks known secret patterns" do
    result = described_class.scan("Please use password=hunter2 for the demo.")

    expect(result).to be_blocked
    expect(result.finding_types).to include("password")
    expect(result.finding_categories).to include("credential")
  end

  it "marks normal meeting text as clear" do
    result = described_class.scan("Decision: ship the review workflow first.")

    expect(result.status).to eq("clear")
    expect(result.findings).to be_empty
  end

  it "detects email addresses as personal data" do
    result = described_class.scan("連絡先は customer@example.com です。")

    expect(result).to be_blocked
    finding = result.findings.find { |item| item.type == "email_address" }
    expect(finding.category).to eq("personal_data")
    expect(finding.location_hint).to eq("メールアドレス")
    expect(finding.suggested_replacement).to eq("[EMAIL_REDACTED]")
  end

  it "detects phone numbers as personal data" do
    result = described_class.scan("緊急連絡先は 090-1234-5678 です。")

    expect(result.finding_types).to include("phone_number")
    expect(result.finding_categories).to include("personal_data")
  end

  it "detects URL tokens as credentials" do
    result = described_class.scan("確認URL: https://example.com/callback?token=abc1234567890secret")

    expect(result.finding_types).to include("url_token")
    expect(result.finding_categories).to include("credential")
  end

  it "detects generic API key-like strings as credentials" do
    result = described_class.scan("api_key=abcdefghijklmnopqrstuvwxyz123456")

    expect(result.finding_types).to include("generic_api_key")
    expect(result.finding_categories).to include("credential")
  end

  it "detects Japanese address-like text as personal data" do
    result = described_class.scan("送付先は東京都渋谷区神南1-2-3です。")

    expect(result.finding_types).to include("japanese_address")
    expect(result.finding_categories).to include("personal_data")
  end

  it "detects financial and legal context" do
    result = described_class.scan("請求書とNDAの内容はDMで確認します。")

    expect(result.finding_categories).to include("financial", "legal")
  end
end
