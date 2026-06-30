require "rails_helper"

RSpec.describe IntegrationAccount, type: :model do
  it "is valid for a connected GitHub App installation" do
    account = build(:integration_account)

    expect(account).to be_valid
    expect(account.github_repository).to eq("Kazuya-Sakashita/ai-pm-platform")
    expect(account).to be_issues_write_granted
  end

  it "requires an installation id when connected" do
    account = build(:integration_account, github_installation_id: nil)

    expect(account).not_to be_valid
    expect(account.errors[:github_installation_id]).to include("can't be blank")
  end

  it "rejects repository names with path separators" do
    account = build(:integration_account, repository_name: "owner/repo")

    expect(account).not_to be_valid
    expect(account.errors[:repository_name]).to be_present
  end
end
