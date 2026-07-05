require "uri"

module Api
  module V1
    class IntegrationAccountsController < ApplicationController
      def index
        return unless require_actor!(action: "integration_read")
        return unless authorize_project_role!(project, action: "integration_read", allowed_roles: project_read_roles)

        accounts = project.integration_accounts.order(created_at: :desc)
        render json: { data: accounts.map(&:api_json) }
      end

      def start_github_connection
        return unless require_actor!(action: "integration_connect")
        return unless authorize_project_role!(project, action: "integration_connect", allowed_roles: project_admin_roles)

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
          actor_id: current_actor_id,
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
        connected_project = nil
        repository = nil
        installation_id = nil

        state_payload = GithubIntegration::ConnectionState.consume!(params.require(:state))
        connected_project = Project.find(state_payload.fetch("project_id"))
        repository = normalized_repository(state_payload.fetch("repository"))
        owner, name = repository.split("/", 2)
        installation_id = params.require(:installation_id)
        verification = GithubIntegration::InstallationVerifier.verify(
          installation_id: installation_id,
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
        record_github_connection_failure(
          project: connected_project,
          repository: repository,
          installation_id: installation_id,
          setup_action: params[:setup_action],
          error: e
        )
        render_error(e.code, e.safe_detail, e.http_status)
      rescue ActionController::ParameterMissing => e
        render_error("validation_error", e.message, :unprocessable_entity)
      end

      def disconnect_github
        return unless require_actor!(action: "integration_disconnect")
        return unless authorize_project_role!(project, action: "integration_disconnect", allowed_roles: project_admin_roles)

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
          actor_id: current_actor_id,
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

      def record_github_connection_failure(project:, repository:, installation_id:, setup_action:, error:)
        return unless project

        AuditLog.record!(
          project: project,
          action: "github.connect.failed",
          target: project,
          summary: "GitHub connection callback failed.",
          metadata: {
            repository: repository,
            setup_action: setup_action,
            github_installation_id: installation_id,
            error_code: error.code,
            safe_error_detail: error.safe_detail
          }.compact
        )
      rescue StandardError => log_error
        Rails.logger.warn(
          event: "github_connection_failure_audit_log_failed",
          project_id: project.id,
          error_class: log_error.class.name
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
