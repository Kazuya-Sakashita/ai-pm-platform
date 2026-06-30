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
end
