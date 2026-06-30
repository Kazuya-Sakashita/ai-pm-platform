require "rails_helper"

RSpec.describe GithubIntegration::ConnectionState do
  it "creates a signed state with a persisted nonce digest" do
    project = create(:project)

    result = described_class.generate(
      project: project,
      repository: "Kazuya-Sakashita/ai-pm-platform",
      redirect_uri: "https://app.ai-pm-platform.test/callback"
    )

    payload = described_class.verify!(result.fetch(:state))
    record = project.github_connection_states.find_by!(
      nonce_digest: described_class.digest(payload.fetch("nonce"))
    )
    expect(payload).to include(
      "project_id" => project.id,
      "repository" => "Kazuya-Sakashita/ai-pm-platform",
      "redirect_uri" => "https://app.ai-pm-platform.test/callback"
    )
    expect(record.state_digest).to eq(described_class.digest(result.fetch(:state)))
    expect(record.github_repository).to eq("Kazuya-Sakashita/ai-pm-platform")
    expect(record.consumed_at).to be_nil
  end

  it "consumes a valid state and rejects replay" do
    project = create(:project)
    state = described_class.generate(
      project: project,
      repository: "Kazuya-Sakashita/ai-pm-platform"
    ).fetch(:state)

    payload = described_class.consume!(state)

    expect(payload).to include("project_id" => project.id, "repository" => "Kazuya-Sakashita/ai-pm-platform")
    expect(project.github_connection_states.last).to be_consumed
    expect {
      described_class.consume!(state)
    }.to raise_error(GithubIntegration::StateError, "GitHub connection state already used.")
  end

  it "rejects states without a matching persisted nonce" do
    project = create(:project)
    state = described_class.verifier.generate(
      {
        project_id: project.id,
        repository: "Kazuya-Sakashita/ai-pm-platform",
        nonce: SecureRandom.hex(32),
        expires_at: 10.minutes.from_now.iso8601
      }
    )

    expect {
      described_class.consume!(state)
    }.to raise_error(GithubIntegration::StateError, "GitHub connection state is invalid.")
  end
end
