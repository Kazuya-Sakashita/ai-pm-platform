require "rails_helper"

RSpec.describe "API V1 Integration Accounts", type: :request do
  around do |example|
    original_slug = ENV["GITHUB_APP_SLUG"]
    original_installation_url = ENV["GITHUB_APP_INSTALLATION_URL"]
    ENV["GITHUB_APP_SLUG"] = "ai-pm-platform"
    ENV.delete("GITHUB_APP_INSTALLATION_URL")
    example.run
  ensure
    ENV["GITHUB_APP_SLUG"] = original_slug
    ENV["GITHUB_APP_INSTALLATION_URL"] = original_installation_url
  end

  describe "GET /api/v1/projects/:project_id/integrations" do
    it "lists project integration accounts" do
      project = create(:project)
      account = create(:integration_account, project: project)

      get "/api/v1/projects/#{project.id}/integrations"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", 0, "id")).to eq(account.id)
      expect(body.dig("data", 0, "provider")).to eq("github")
      expect(body.dig("data", 0, "granted_permissions")).to include("issues" => "write")
    end
  end

  describe "POST /api/v1/projects/:project_id/integrations/github/connect" do
    it "starts a GitHub App installation flow with a signed state" do
      project = create(:project, github_repo: "Kazuya-Sakashita/ai-pm-platform")

      post "/api/v1/projects/#{project.id}/integrations/github/connect", params: {
        repository: "Kazuya-Sakashita/ai-pm-platform"
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "installation_url")).to start_with("https://github.com/apps/ai-pm-platform/installations/new?")
      expect(body.dig("data", "state")).to be_present
      expect(body.dig("data", "expires_at")).to be_present
      state_payload = GithubIntegration::ConnectionState.verify!(body.dig("data", "state"))
      expect(state_payload).to include(
        "project_id" => project.id,
        "repository" => "Kazuya-Sakashita/ai-pm-platform"
      )
      expect(project.audit_logs.last.action).to eq("github.connect.started")
    end

    it "blocks a repository that does not match the project configuration" do
      project = create(:project, github_repo: "Kazuya-Sakashita/ai-pm-platform")

      post "/api/v1/projects/#{project.id}/integrations/github/connect", params: {
        repository: "Other/repository"
      }

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_repository_mismatch")
    end
  end

  describe "POST /api/v1/integrations/github/callback" do
    it "creates a connected GitHub integration account from a valid state" do
      project = create(:project, github_repo: "Kazuya-Sakashita/ai-pm-platform")
      state = GithubIntegration::ConnectionState.generate(
        project: project,
        repository: "Kazuya-Sakashita/ai-pm-platform"
      ).fetch(:state)
      allow(GithubIntegration::InstallationVerifier).to receive(:verify).and_return(
        GithubIntegration::InstallationVerifier::Result.new(
          installation_id: "987654",
          account_login: "Kazuya-Sakashita",
          account_type: "User",
          granted_permissions: {
            "metadata" => "read",
            "issues" => "write"
          }
        )
      )

      post "/api/v1/integrations/github/callback", params: {
        state: state,
        installation_id: "987654",
        setup_action: "install"
      }

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("connected")
      expect(body.dig("data", "github_installation_id")).to eq("987654")
      expect(body.dig("data", "repository_owner")).to eq("Kazuya-Sakashita")
      expect(body.dig("data", "repository_name")).to eq("ai-pm-platform")
      expect(body.dig("data", "granted_permissions")).to include("issues" => "write")
      expect(project.integration_accounts.last).to be_issues_write_granted
      expect(project.github_connection_states.last).to be_consumed
      expect(project.audit_logs.last.action).to eq("github.connect.completed")
      expect(GithubIntegration::InstallationVerifier).to have_received(:verify).with(
        installation_id: "987654",
        repository: "Kazuya-Sakashita/ai-pm-platform"
      )
    end

    it "rejects an invalid state" do
      post "/api/v1/integrations/github/callback", params: {
        state: "invalid-state",
        installation_id: "987654",
        granted_permissions: {
          metadata: "read",
          issues: "write"
        }
      }

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_state_invalid")
    end

    it "returns a safe error and consumes the state when GitHub installation verification fails" do
      project = create(:project, github_repo: "Kazuya-Sakashita/ai-pm-platform")
      state = GithubIntegration::ConnectionState.generate(
        project: project,
        repository: "Kazuya-Sakashita/ai-pm-platform"
      ).fetch(:state)
      allow(GithubIntegration::InstallationVerifier).to receive(:verify).and_raise(
        GithubIntegration::VerifierError.new(
          code: "github_installation_verification_failed",
          message: "GitHub installation verification failed with status 404.",
          safe_detail: "GitHub installation could not be verified."
        )
      )

      post "/api/v1/integrations/github/callback", params: {
        state: state,
        installation_id: "987654",
        setup_action: "install"
      }

      expect(response).to have_http_status(:failed_dependency)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_installation_verification_failed")
      expect(body.dig("error", "message")).to eq("GitHub installation could not be verified.")
      expect(project.integration_accounts).to be_empty
      expect(project.github_connection_states.last).to be_consumed
      failure_log = project.audit_logs.find_by!(action: "github.connect.failed")
      expect(failure_log.metadata).to include(
        "repository" => "Kazuya-Sakashita/ai-pm-platform",
        "setup_action" => "install",
        "github_installation_id" => "987654",
        "error_code" => "github_installation_verification_failed",
        "safe_error_detail" => "GitHub installation could not be verified."
      )
      expect(failure_log.metadata).not_to include("state")
      expect(failure_log.metadata).not_to include("nonce")

      post "/api/v1/integrations/github/callback", params: {
        state: state,
        installation_id: "987654"
      }

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_state_invalid")
      expect(body.dig("error", "message")).to eq("GitHub connection state already used.")
      expect(GithubIntegration::InstallationVerifier).to have_received(:verify).once
    end

    it "rejects replayed connection states" do
      project = create(:project, github_repo: "Kazuya-Sakashita/ai-pm-platform")
      state = GithubIntegration::ConnectionState.generate(
        project: project,
        repository: "Kazuya-Sakashita/ai-pm-platform"
      ).fetch(:state)
      verification = GithubIntegration::InstallationVerifier::Result.new(
        installation_id: "987654",
        account_login: "Kazuya-Sakashita",
        account_type: "User",
        granted_permissions: {
          "metadata" => "read",
          "issues" => "write"
        }
      )
      allow(GithubIntegration::InstallationVerifier).to receive(:verify).and_return(verification)

      2.times do
        post "/api/v1/integrations/github/callback", params: {
          state: state,
          installation_id: "987654"
        }
      end

      expect(response).to have_http_status(:unauthorized)
      body = JSON.parse(response.body)
      expect(body.dig("error", "code")).to eq("github_state_invalid")
      expect(body.dig("error", "message")).to eq("GitHub connection state already used.")
      expect(GithubIntegration::InstallationVerifier).to have_received(:verify).once
    end
  end

  describe "POST /api/v1/projects/:project_id/integrations/github/disconnect" do
    it "marks the latest GitHub integration as revoked" do
      project = create(:project)
      account = create(:integration_account, project: project)

      post "/api/v1/projects/#{project.id}/integrations/github/disconnect"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig("data", "status")).to eq("revoked")
      expect(account.reload.status).to eq("revoked")
      expect(project.audit_logs.last.action).to eq("github.disconnect")
    end
  end
end
