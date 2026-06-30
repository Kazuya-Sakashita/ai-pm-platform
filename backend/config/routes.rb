Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      get "health", to: "health#show"

      resources :projects, only: %i[index show create update destroy] do
        resources :meetings, only: %i[index create]
        resources :audit_logs, only: %i[index], path: "audit-logs"
      end

      resources :meetings, only: %i[show] do
        post "generate-minutes", to: "minutes#generate", on: :member
      end
      resources :minutes, only: %i[show update] do
        post "approve", on: :member
        post "generate-requirement", to: "requirements#generate", on: :member
      end
      resources :requirements, only: %i[show update] do
        post "approve", on: :member
        post "generate-issue-draft", to: "issue_drafts#generate", on: :member
        post "generate-openapi-draft", to: "open_api_drafts#generate", on: :member
      end
      resources :issue_drafts, only: %i[show update], path: "issue-drafts"
      resources :openapi_drafts, only: %i[show update], controller: "open_api_drafts", path: "openapi-drafts", param: :openapi_draft_id do
        post "validate", on: :member
      end
      resources :reviews, only: %i[index create] do
        post "resolve-action", to: "reviews#resolve_action", on: :member
        post "accept-risk", to: "reviews#accept_risk", on: :member
      end
      resources :jobs, only: %i[show]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
