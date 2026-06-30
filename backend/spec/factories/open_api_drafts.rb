FactoryBot.define do
  factory :open_api_draft do
    requirement { association :requirement, status: "approved", open_questions: [] }
    status { "draft" }
    title { "OpenAPI draft: Generate approved requirement API" }
    content do
      <<~YAML
        openapi: 3.1.0
        info:
          title: OpenAPI draft: Generate approved requirement API
          version: 0.1.0
        paths: {}
      YAML
    end
    validation_errors { [] }
    generated_by_model { "deterministic-openapi-draft-placeholder-v1" }
  end
end
