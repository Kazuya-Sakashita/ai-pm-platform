Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"
      get "auth/sessions", to: "auth_sessions#index"
      delete "auth/sessions/current", to: "auth_sessions#destroy_current"
      delete "auth/sessions/:auth_session_id", to: "auth_sessions#destroy"
      post "auth/logout-everywhere", to: "auth_sessions#logout_everywhere"

      resources :projects, only: %i[index show create update destroy] do
        resources :meetings, only: %i[index create]
        resources :project_memberships, only: %i[index create update destroy], path: "memberships", param: :membership_id
        resources :conversation_imports, only: %i[index create], path: "conversation-imports"
        resources :audit_logs, only: %i[index], path: "audit-logs"
        resources :integration_accounts, only: %i[index], path: "integrations"
        post "integrations/github/connect", to: "integration_accounts#start_github_connection"
        post "integrations/github/disconnect", to: "integration_accounts#disconnect_github"
      end
      resources :conversation_imports, only: %i[show update destroy], path: "conversation-imports", param: :conversation_import_id do
        post "scan", on: :member
        post "generate-summary", on: :member
      end
      resources :conversation_summary_drafts, only: %i[show update], path: "conversation-summary-drafts", param: :conversation_summary_draft_id do
        post "approve", on: :member
      end
      post "integrations/github/callback", to: "integration_accounts#github_callback"

      resources :meetings, only: %i[show] do
        post "generate-minutes", to: "minutes#generate", on: :member
      end
      resources :minutes, only: %i[show update] do
        post "approve", on: :member
        post "generate-requirement", to: "requirements#generate", on: :member
      end
      resources :requirements, only: %i[show update] do
        get "history", on: :member
        post "approve", on: :member
        post "generate-issue-draft", to: "issue_drafts#generate", on: :member
        post "generate-openapi-draft", to: "open_api_drafts#generate", on: :member
      end
      resources :issue_drafts, only: %i[show update], path: "issue-drafts", param: :issue_draft_id do
        post "publish-github", on: :member
        post "reconcile-github-publish", on: :member
        post "resolve-github-reconciliation", on: :member
      end
      resources :openapi_drafts, only: %i[show update], controller: "open_api_drafts", path: "openapi-drafts", param: :openapi_draft_id do
        post "validate", on: :member
      end
      resources :reviews, only: %i[index create] do
        get "events", to: "reviews#events", on: :member
        post "resolve-action", to: "reviews#resolve_action", on: :member
        post "accept-risk", to: "reviews#accept_risk", on: :member
        post "reopen", to: "reviews#reopen", on: :member
      end
      resources :jobs, only: %i[show]
      get "operations/queue-health", to: "operations#queue_health"
      post "operations/failed-jobs/:failed_job_id/retry", to: "operations#retry_failed_job"
      post "operations/failed-jobs/:failed_job_id/discard", to: "operations#discard_failed_job"
      post "operations/failed-jobs/:failed_job_id/discard-approval-requests", to: "operations#request_failed_job_discard_approval"
      post "operations/failed-job-discard-approvals/:approval_id/approve", to: "operations#approve_failed_job_discard_approval"
      post "operations/failed-job-discard-approvals/:approval_id/reject", to: "operations#reject_failed_job_discard_approval"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
