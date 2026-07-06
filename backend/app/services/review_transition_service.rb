class ReviewTransitionService
  REDACTED_SUMMARY = "機密情報を含むため非表示".freeze
  SUMMARY_LIMIT = 160
  MAX_TEXT_LENGTH = 1_000
  USER_TEXT_KEYS = %i[
    positives
    improvements
    priority
    next_actions
    resolution_note
    reason
    residual_risk
  ].freeze

  SensitiveContentError = Class.new(StandardError) do
    attr_reader :details

    def initialize(details)
      @details = details
      super("Review text contains sensitive content.")
    end
  end

  InvalidTransitionError = Class.new(StandardError) do
    attr_reader :code, :details

    def initialize(code, details = {})
      @code = code
      @details = details
      super(code)
    end
  end

  def initialize(project:, actor_id: "system", sensitive_handling: :reject)
    @project = project
    @actor_id = actor_id.presence || "system"
    @sensitive_handling = sensitive_handling
  end

  def create!(attributes)
    sanitized = sanitize_review_attributes(attributes)

    Review.transaction do
      review = Review.create!(sanitized.merge(status: "open"))
      record_event!(
        review,
        event_type: "review_requested",
        from_status: nil,
        to_status: "open",
        reason_code: sanitized[:reason_code],
        reason_text: Array(sanitized[:next_actions]).first,
        issue_numbers: sanitized[:issue_numbers]
      )
      review
    end
  end

  def mark_action_required!(review:, attributes:, reason_code: nil, reason_text: nil)
    sanitized = sanitize_review_attributes(attributes)

    Review.transaction do
      from_status = review.status unless review.new_record?
      review.assign_attributes(sanitized.merge(status: "action_required", resolution_note: nil))
      review.save!
      record_event_if_transition!(
        review,
        event_type: "review_action_required",
        from_status: from_status,
        to_status: "action_required",
        reason_code: reason_code,
        reason_text: reason_text || Array(sanitized[:improvements]).first,
        issue_numbers: sanitized[:issue_numbers]
      )
      review
    end
  end

  def resolve!(review:, resolution_note:, reason_code: "review_resolved", issue_numbers: nil)
    ensure_transition_allowed!(review, to_status: "resolved", allowed_from: %w[open action_required])
    sanitized_note = sanitize_text_value(:resolution_note, resolution_note)

    Review.transaction do
      from_status = review.status
      review.update!(status: "resolved", resolution_note: sanitized_note)
      record_event!(
        review,
        event_type: "review_resolved",
        from_status: from_status,
        to_status: "resolved",
        reason_code: reason_code,
        reason_text: sanitized_note,
        issue_numbers: issue_numbers || review.issue_numbers
      )
      review
    end
  end

  def accept_risk!(review:, reason:, residual_risk:, expires_at:, linked_issue_number:)
    ensure_transition_allowed!(review, to_status: "accepted_risk", allowed_from: %w[open action_required])
    sanitized_reason = sanitize_text_value(:reason, reason)
    sanitized_residual_risk = sanitize_text_value(:residual_risk, residual_risk)

    Review.transaction do
      from_status = review.status
      review.update!(
        status: "accepted_risk",
        accepted_risk: {
          reason: sanitized_reason,
          residual_risk: sanitized_residual_risk,
          approved_by: actor_id,
          expires_at: expires_at,
          linked_issue_number: linked_issue_number,
          accepted_at: Time.current.iso8601
        }
      )
      record_event!(
        review,
        event_type: "review_risk_accepted",
        from_status: from_status,
        to_status: "accepted_risk",
        reason_code: "risk_accepted",
        reason_text: sanitized_reason,
        issue_numbers: [linked_issue_number].compact
      )
      review
    end
  end

  def reopen!(review:, reason_summary:, issue_numbers: nil)
    ensure_transition_allowed!(review, to_status: "open", allowed_from: %w[resolved accepted_risk action_required])
    sanitized_reason = sanitize_text_value(:reason_summary, reason_summary)

    Review.transaction do
      from_status = review.status
      review.update!(status: "open", resolution_note: nil, accepted_risk: nil)
      record_event!(
        review,
        event_type: "review_reopened",
        from_status: from_status,
        to_status: "open",
        reason_code: "review_reopened",
        reason_text: sanitized_reason,
        issue_numbers: issue_numbers || review.issue_numbers
      )
      review
    end
  end

  private

  attr_reader :project, :actor_id, :sensitive_handling

  def record_event_if_transition!(review, event_type:, from_status:, to_status:, reason_code:, reason_text:, issue_numbers:)
    return if from_status == to_status

    record_event!(
      review,
      event_type: event_type,
      from_status: from_status,
      to_status: to_status,
      reason_code: reason_code,
      reason_text: reason_text,
      issue_numbers: issue_numbers
    )
  end

  def record_event!(review, event_type:, from_status:, to_status:, reason_code:, reason_text:, issue_numbers:)
    summary = safe_summary(reason_text)
    ReviewStateEvent.create!(
      review: review,
      project: project,
      target_type: review.target_type,
      target_id: review.target_id,
      event_type: event_type,
      from_status: from_status,
      to_status: to_status,
      actor_id: actor_id,
      reason_code: reason_code,
      reason_summary: summary.fetch(:text),
      issue_numbers: Array(issue_numbers).compact,
      metadata: summary.fetch(:metadata),
      occurred_at: Time.current
    )
  end

  def ensure_transition_allowed!(review, to_status:, allowed_from:)
    return if allowed_from.include?(review.status)

    raise InvalidTransitionError.new(
      "invalid_review_transition",
      {
        review_id: review.id,
        from_status: review.status,
        to_status: to_status,
        allowed_from: allowed_from
      }
    )
  end

  def sanitize_review_attributes(attributes)
    sanitized = attributes.to_h.with_indifferent_access.deep_dup
    USER_TEXT_KEYS.each do |key|
      next unless sanitized.key?(key)

      sanitized[key] = sanitize_text_value(key, sanitized[key])
    end
    sanitized
  end

  def sanitize_text_value(key, value)
    if value.is_a?(Array)
      return value.map { |item| sanitize_text_value(key, item) }
    end

    text = value.to_s
    if text.length > MAX_TEXT_LENGTH && sensitive_handling == :redact
      text = "#{text[0, MAX_TEXT_LENGTH]}..."
    elsif text.length > MAX_TEXT_LENGTH
      raise SensitiveContentError.new(
        field: key.to_s,
        reason: "too_long",
        max_length: MAX_TEXT_LENGTH
      )
    end

    scan_result = SensitiveContentScanner.scan(text)
    return text unless scan_result.blocked?

    if sensitive_handling == :redact
      REDACTED_SUMMARY
    else
      raise SensitiveContentError.new(
        field: key.to_s,
        finding_categories: scan_result.finding_categories,
        finding_types: scan_result.finding_types
      )
    end
  end

  def safe_summary(text)
    raw_text = text.to_s.strip
    return { text: nil, metadata: { reason_present: false, redacted: false } } if raw_text.blank?

    scan_result = SensitiveContentScanner.scan(raw_text)
    metadata = {
      reason_present: true,
      redacted: scan_result.blocked?,
      original_length: raw_text.length
    }

    if scan_result.blocked?
      metadata[:finding_categories] = scan_result.finding_categories
      metadata[:finding_types] = scan_result.finding_types
      return { text: REDACTED_SUMMARY, metadata: metadata }
    end

    summary = raw_text.length > SUMMARY_LIMIT ? "#{raw_text[0, SUMMARY_LIMIT]}..." : raw_text
    metadata[:truncated] = raw_text.length > SUMMARY_LIMIT
    { text: summary, metadata: metadata }
  end
end
