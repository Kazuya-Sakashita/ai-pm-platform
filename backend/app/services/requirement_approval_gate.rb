class RequirementApprovalGate
  BLOCKING_REVIEW_STATUSES = %w[open action_required].freeze

  Result = Struct.new(:allowed, :code, :message, :details, keyword_init: true)

  def initialize(requirement)
    @requirement = requirement
  end

  def call
    return open_questions_blocker if requirement.open_questions.any?

    blockers = unresolved_review_blockers.to_a
    expired_risk_blockers = expired_accepted_risk_blockers
    return review_blocker(blockers, expired_risk_blockers) if blockers.any? || expired_risk_blockers.any?

    Result.new(allowed: true, details: { requirement_id: requirement.id })
  end

  private

  attr_reader :requirement

  def open_questions_blocker
    Result.new(
      allowed: false,
      code: "review_required",
      message: "要件定義の未決事項を解決してから承認してください。",
      details: { requirement_id: requirement.id, open_questions: requirement.open_questions }
    )
  end

  def review_blocker(blockers, expired_risk_blockers)
    all_blockers = blockers + expired_risk_blockers
    Result.new(
      allowed: false,
      code: "review_required",
      message: "要件定義レビューを解決するか、有効期限内のリスク受容にしてから承認してください。",
      details: {
        requirement_id: requirement.id,
        review_ids: all_blockers.map(&:id),
        review_statuses: all_blockers.to_h { |review| [review.id, review.status] },
        expired_accepted_risk_review_ids: expired_risk_blockers.map(&:id),
        accepted_risk_expires_at: expired_risk_blockers.to_h do |review|
          [review.id, accepted_risk_expires_at_value(review)]
        end
      }
    )
  end

  def unresolved_review_blockers
    Review.where(
      target_type: "requirement",
      target_id: requirement.id,
      status: BLOCKING_REVIEW_STATUSES
    ).order(created_at: :asc)
  end

  def expired_accepted_risk_blockers
    Review.where(
      target_type: "requirement",
      target_id: requirement.id,
      status: "accepted_risk"
    ).order(created_at: :asc).select { |review| accepted_risk_expired?(review) }
  end

  def accepted_risk_expired?(review)
    expires_at = accepted_risk_expires_at(review)
    expires_at.nil? || expires_at <= Time.current
  end

  def accepted_risk_expires_at(review)
    value = accepted_risk_expires_at_value(review)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def accepted_risk_expires_at_value(review)
    risk = review.accepted_risk.to_h
    risk["expires_at"] || risk[:expires_at]
  end
end
