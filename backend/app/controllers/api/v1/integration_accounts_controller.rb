require "uri"

module Api
  module V1
    class IntegrationAccountsController < ApplicationController
      def index
        accounts = project.integration_accounts.order(created_at: :desc)
        render json: { data: accounts.map(&:api_json) }
      end

      def start_github_connection
        repository = normalized_repository(params.require(:repository))
        return render_repository_mismatch(repository) unless repository_allowed?(repository)

        state_payload = GithubIntegration::ConnectionState.generate(
          project: project,
          repository: repository,
          redirect_uri: params[:redirect_uri]
        )

        AuditLog.record!(
          project: project,
          action: "github.connect.started",
          target: project,
          metadata: { repository: repository }
        )

        render json: {
          data: {
            installation_url: github_installation_url(state_payload.fetch(:state)),
            state: state_payload.fetch(:state),
            expires_at: state_payload.fetch(:expires_at).iso8601
          }
        }
      rescue ActionController::ParameterMissing => e
        render_error("validation_error", e.message, :unprocessable_entity)
      end

      def github_callback
        state_payload = GithubIntegration::ConnectionState.consume!(params.require(:state))
        connected_project = Project.find(state_payload.fetch("project_id"))
        repository = normalized_repository(state_payload.fetch("repository"))
        owner, name = repository.split("/", 2)
        verification = GithubIntegration::InstallationVerifier.verify(
          installation_id: params.require(:installation_id),
          repository: repository
        )

        account = connected_project.integration_accounts.find_or_initialize_by(
          provider: "github",
          repository_owner: owner,
          repository_name: name
        )
        account.assign_attributes(github_callback_attributes(verification))
        account.save!
        connected_project.update!(github_repo: repository) if connected_project.github_repo.blank?

        AuditLog.record!(
          project: connected_project,
          action: "github.connect.completed",
          target: account,
          metadata: {
            repository: repository,
            setup_action: params[:setup_action],
            github_installation_id: account.github_installation_id
          }.compact
        )

        render json: { data: account.api_json }
      rescue GithubIntegration::StateError => e
        render_error("github_state_invalid", e.message, :unauthorized)
      rescue GithubIntegration::VerifierError => e
        render_error(e.code, e.safe_detail, e.http_status)
      rescue ActionController::ParameterMissing => e
        render_error("validation_error", e.message, :unprocessable_entity)
      end

      def disconnect_github
        account = project.integration_accounts
                         .where(provider: "github")
                         .order(updated_at: :desc)
                         .first!
        account.update!(
          status: "revoked",
          last_error_safe: nil,
          last_sync_at: Time.current
        )

        AuditLog.record!(
          project: project,
          action: "github.disconnect",
          target: account,
          metadata: { repository: account.github_repository }
        )

        render json: { data: account.api_json }
      end

      private

      def project
        @project ||= Project.find(params[:project_id])
      end

      def github_callback_attributes(verification)
        {
          status: "connected",
          external_account_id: verification.installation_id,
          github_installation_id: verification.installation_id,
          github_account_login: verification.account_login,
          github_account_type: verification.account_type,
          granted_permissions: verification.granted_permissions,
          last_error_safe: nil,
          last_sync_at: Time.current
        }
      end

      def normalized_repository(value)
        repository = value.to_s.strip
        owner, name = repository.split("/", 2)
        raise ActionController::ParameterMissing, "repository must be owner/name" if owner.blank? || name.blank?

        "#{owner}/#{name}"
      end

      def repository_allowed?(repository)
        project.github_repo.blank? || project.github_repo.casecmp?(repository)
      end

      def render_repository_mismatch(repository)
        render_error(
          "github_repository_mismatch",
          "Repository does not match the project GitHub repository.",
          :unprocessable_entity,
          { project_repository: project.github_repo, requested_repository: repository }
        )
      end

      def github_installation_url(state)
        base_url = ENV["GITHUB_APP_INSTALLATION_URL"].presence || default_installation_url
        uri = URI.parse(base_url)
        query = URI.decode_www_form(uri.query.to_s)
        query << ["state", state]
        uri.query = URI.encode_www_form(query)
        uri.to_s
      end

      def default_installation_url
        app_slug = ENV["GITHUB_APP_SLUG"].presence
        return "https://github.com/apps/#{app_slug}/installations/new" if app_slug

        raise ActionController::ParameterMissing, "GITHUB_APP_SLUG or GITHUB_APP_INSTALLATION_URL must be configured"
      end
    end
  end
end
