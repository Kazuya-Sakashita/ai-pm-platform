require "yaml"

class OpenApiDraftValidationService
  HTTP_METHODS = %w[get post put patch delete options head trace].freeze
  VALID_STATUS_PRESERVE = %w[in_review approved].freeze

  def initialize(open_api_draft)
    @open_api_draft = open_api_draft
    @errors = []
    @warnings = []
  end

  def call
    document = parse_document
    validate_document(document) if document

    valid = errors.empty?
    open_api_draft.update!(
      status: next_status(valid),
      validation_errors: errors.map { |issue| "#{issue[:path]}: #{issue[:message]}" }
    )

    {
      valid: valid,
      errors: errors,
      warnings: warnings
    }
  end

  private

  attr_reader :open_api_draft, :errors, :warnings

  def next_status(valid)
    return "invalid" unless valid
    return open_api_draft.status if VALID_STATUS_PRESERVE.include?(open_api_draft.status)

    "valid"
  end

  def parse_document
    document = YAML.safe_load(open_api_draft.content, aliases: false)
    return document if document.is_a?(Hash)

    add_error("$", "OpenAPI content must be a YAML object.", "invalid_document")
    nil
  rescue Psych::SyntaxError => e
    add_error("$", "OpenAPI YAML syntax error: #{e.problem}.", "yaml_syntax_error")
    nil
  end

  def validate_document(document)
    validate_openapi_version(document)
    validate_info(document["info"])
    validate_paths(document["paths"])
    validate_components(document["components"])
  end

  def validate_openapi_version(document)
    version = document["openapi"]
    if version.blank?
      add_error("$.openapi", "OpenAPI version is required.", "missing_openapi_version")
    elsif !version.to_s.start_with?("3.")
      add_error("$.openapi", "OpenAPI version must be 3.x.", "unsupported_openapi_version")
    end
  end

  def validate_info(info)
    unless info.is_a?(Hash)
      add_error("$.info", "Info object is required.", "missing_info")
      return
    end

    add_error("$.info.title", "Info title is required.", "missing_info_title") if info["title"].blank?
    add_error("$.info.version", "Info version is required.", "missing_info_version") if info["version"].blank?
  end

  def validate_paths(paths)
    unless paths.is_a?(Hash)
      add_error("$.paths", "Paths object is required.", "missing_paths")
      return
    end

    if paths.empty?
      add_error("$.paths", "At least one path is required.", "empty_paths")
      return
    end

    paths.each do |path, path_item|
      validate_path_item(path, path_item)
    end
  end

  def validate_path_item(path, path_item)
    unless path.to_s.start_with?("/")
      add_error("$.paths.#{path}", "Path must start with '/'.", "invalid_path_name")
    end

    unless path_item.is_a?(Hash)
      add_error("$.paths.#{path}", "Path item must be an object.", "invalid_path_item")
      return
    end

    operations = path_item.select { |method, _operation| HTTP_METHODS.include?(method.to_s.downcase) }
    add_error("$.paths.#{path}", "At least one HTTP operation is required.", "missing_operation") if operations.empty?

    operations.each do |method, operation|
      validate_operation(path, method, operation)
    end
  end

  def validate_operation(path, method, operation)
    pointer = "$.paths.#{path}.#{method}"
    unless operation.is_a?(Hash)
      add_error(pointer, "Operation must be an object.", "invalid_operation")
      return
    end

    add_error("#{pointer}.operationId", "operationId is required.", "missing_operation_id") if operation["operationId"].blank?
    add_warning("#{pointer}.summary", "summary is recommended.", "missing_summary") if operation["summary"].blank?

    responses = operation["responses"]
    if responses.is_a?(Hash) && responses.any?
      add_warning("#{pointer}.responses", "At least one 4xx/5xx error response is recommended.", "missing_error_response") unless responses.keys.any? { |code| code.to_s.match?(/\A[45]/) }
    else
      add_error("#{pointer}.responses", "At least one response is required.", "missing_responses")
    end
  end

  def validate_components(components)
    return add_warning("$.components", "components.schemas is recommended.", "missing_components") unless components.is_a?(Hash)

    schemas = components["schemas"]
    add_warning("$.components.schemas", "At least one reusable schema is recommended.", "missing_component_schemas") unless schemas.is_a?(Hash) && schemas.any?
  end

  def add_error(path, message, code)
    errors << issue(path, message, "error", code)
  end

  def add_warning(path, message, code)
    warnings << issue(path, message, "warning", code)
  end

  def issue(path, message, severity, code)
    {
      path: path,
      message: message,
      severity: severity,
      code: code
    }
  end
end
