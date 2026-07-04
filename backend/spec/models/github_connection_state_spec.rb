require "rails_helper"

RSpec.describe GithubConnectionState, type: :model do
  it "consumes an unused state once" do
    state = create(:github_connection_state)

    expect { state.consume! }.to change { state.reload.consumed? }.from(false).to(true)
  end

  it "rejects replay after consumption" do
    state = create(:github_connection_state, consumed_at: Time.current)

    expect {
      state.consume!
    }.to raise_error(GithubIntegration::StateError, "GitHub connection state already used.")
  end

  it "rejects expired states" do
    state = create(:github_connection_state, expires_at: 1.minute.ago)

    expect {
      state.consume!
    }.to raise_error(GithubIntegration::StateError, "GitHub connection state expired.")
  end

  it "deletes only expired states older than the cleanup retention" do
    old_expired_state = create(:github_connection_state, expires_at: 25.hours.ago)
    recent_expired_state = create(:github_connection_state, expires_at: 23.hours.ago)
    active_state = create(:github_connection_state, expires_at: 1.minute.from_now)

    expect {
      deleted_count = described_class.cleanup_expired!(now: Time.current)
      expect(deleted_count).to eq(1)
    }.to change(described_class, :count).by(-1)

    expect(described_class.exists?(old_expired_state.id)).to be(false)
    expect(described_class.exists?(recent_expired_state.id)).to be(true)
    expect(described_class.exists?(active_state.id)).to be(true)
  end
end
