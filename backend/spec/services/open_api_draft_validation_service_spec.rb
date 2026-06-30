require "rails_helper"

RSpec.describe OpenApiDraftValidationService do
  it "marks a valid OpenAPI draft as valid" do
    open_api_draft = create(:open_api_draft, status: "draft", validation_errors: ["stale error"])

    result = described_class.new(open_api_draft).call

    expect(result.fetch(:valid)).to be(true)
    expect(result.fetch(:errors)).to eq([])
    expect(result.fetch(:warnings)).to eq([])
    expect(open_api_draft.reload.status).to eq("valid")
    expect(open_api_draft.validation_errors).to eq([])
  end

  it "does not overwrite in-review or approved status when the draft is valid" do
    approved_draft = create(:open_api_draft, status: "approved", validation_errors: ["stale error"])
    in_review_draft = create(:open_api_draft, status: "in_review", validation_errors: ["stale error"])

    approved_result = described_class.new(approved_draft).call
    in_review_result = described_class.new(in_review_draft).call

    expect(approved_result.fetch(:valid)).to be(true)
    expect(in_review_result.fetch(:valid)).to be(true)
    expect(approved_draft.reload.status).to eq("approved")
    expect(in_review_draft.reload.status).to eq("in_review")
    expect(approved_draft.validation_errors).to eq([])
    expect(in_review_draft.validation_errors).to eq([])
  end

  it "marks YAML syntax errors as invalid" do
    open_api_draft = create(:open_api_draft, content: "openapi: [")

    result = described_class.new(open_api_draft).call

    expect(result.fetch(:valid)).to be(false)
    expect(result.fetch(:errors).first).to include(path: "$", severity: "error", code: "yaml_syntax_error")
    expect(open_api_draft.reload.status).to eq("invalid")
    expect(open_api_draft.validation_errors.first).to include("OpenAPI YAML syntax error")
  end

  it "captures structural errors and quality warnings" do
    open_api_draft = create(
      :open_api_draft,
      content: <<~YAML
        openapi: 3.1.0
        info:
          title: Missing version
        paths:
          generated:
            post:
              responses:
                "200":
                  description: OK
      YAML
    )

    result = described_class.new(open_api_draft).call

    expect(result.fetch(:valid)).to be(false)
    expect(result.fetch(:errors).map { |issue| issue.fetch(:code) }).to include("missing_info_version", "invalid_path_name", "missing_operation_id")
    expect(result.fetch(:warnings).map { |issue| issue.fetch(:code) }).to include("missing_summary", "missing_error_response", "missing_components")
    expect(open_api_draft.reload.validation_errors).to include(a_string_including("Info version is required"))
  end
end
