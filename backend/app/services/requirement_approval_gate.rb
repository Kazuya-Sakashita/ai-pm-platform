class RequirementApprovalGate
  BLOCKING_REVIEW_STATUSES = %w[open action_required].freeze

  Result = Struct.new(:allowed, :code, :message, :details, keyword_init: true)

  def initialize(requirement)
    @requirement = requirement
  end

  def call
    return open_questions_blocker if requirement.open_questions.any?

    blockers = unresolved_review_blockers
    return review_blocker(blockers) if blockers.any?

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

  def review_blocker(blockers)
    Result.new(
      allowed: false,
      code: "review_required",
      message: "要件定義レビューを解決またはリスク受容してから承認してください。",
      details: {
        requirement_id: requirement.id,
        review_ids: blockers.map(&:id),
        review_statuses: blockers.to_h { |review| [review.id, review.status] }
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
end
