require "rails_helper"

RSpec.describe GithubIntegration::ConnectionStateCleanupJob, type: :job do
  it "uses the default maintenance queue" do
    expect(described_class.queue_name).to eq("default")
  end

  it "removes expired connection states older than the retention window" do
    old_expired_state = create(:github_connection_state, expires_at: 26.hours.ago)
    recent_expired_state = create(:github_connection_state, expires_at: 30.minutes.ago)
    active_state = create(:github_connection_state, expires_at: 10.minutes.from_now)

    expect {
      described_class.perform_now
    }.to change(GithubConnectionState, :count).by(-1)

    expect(GithubConnectionState.exists?(old_expired_state.id)).to be(false)
    expect(GithubConnectionState.exists?(recent_expired_state.id)).to be(true)
    expect(GithubConnectionState.exists?(active_state.id)).to be(true)
  end

  it "accepts a custom retention in seconds for operational tuning" do
    old_expired_state = create(:github_connection_state, expires_at: 2.hours.ago)
    recent_expired_state = create(:github_connection_state, expires_at: 30.minutes.ago)

    described_class.perform_now(1.hour.to_i)

    expect(GithubConnectionState.exists?(old_expired_state.id)).to be(false)
    expect(GithubConnectionState.exists?(recent_expired_state.id)).to be(true)
  end
end
