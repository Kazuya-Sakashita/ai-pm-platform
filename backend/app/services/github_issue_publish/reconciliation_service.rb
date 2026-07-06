module GithubIssuePublish
  class ReconciliationService
    DEFAULT_RETRY_COOLDOWN = 60.seconds
    REVIEWER_ROLE = "GitHub Publish Reconciler"
    FRAMEWORK = ["G-STACK", "STRIDE", "ISO25010"].freeze
    Result = Struct.new(
      :status,
      :matches,
      :review,
      :search_total_count,
      :search_incomplete_results,
      :search_result_limit,
      :reconciliation_retry_count,
      :next_reconciliation_retry_at,
      keyword_init: true
    ) do
      def search_has_more_results
        search_total_count.to_i > matches.count
      end

      def reconciliation_cooldown_active
        next_reconciliation_retry_at.present? && next_reconciliation_retry_at > Time.current
      end
    end

    def initialize(attempt, search_client: MarkerSearchClient.new)
      @attempt = attempt
      @search_client = search_client
    end

    def call
      search_result = normalize_search_result(
        search_client.search(
          issue_draft: issue_draft,
          project: project,
          idempotency_digest: attempt.idempotency_digest
        )
      )
      matches = search_result.matches

      return block_for_human_review!(matches, search_result) if search_result.incomplete_results
      return reconcile!(matches.first, search_result) if matches.one?

      block_for_human_review!(matches, search_result)
    rescue ProviderError => e
      available_at = retry_available_at(e) if retryable_provider_error?(e) && attempt.reconciliation_retry_count < GithubIssuePublishAttempt::MAX_RECONCILIATION_RETRY_COUNT
      attributes = {
        safe_error_code: e.code,
        safe_error_detail: e.safe_detail,
        completed_at: Time.current
      }
      attempt.update!(attributes)
      schedule_retry!(available_at: available_at) if available_at
      raise
    end

    private

    attr_reader :attempt, :search_client

    def normalize_search_result(raw_result)
      return raw_result if raw_result.respond_to?(:matches)

      MarkerSearchClient::SearchResult.new(
        matches: raw_result,
        total_count: raw_result.count,
        incomplete_results: false,
        result_limit: MarkerSearchClient::SEARCH_RESULT_LIMIT
      )
    end

    def result_attributes(search_result)
      {
        search_total_count: search_result.total_count,
        search_incomplete_results: search_result.incomplete_results,
        search_result_limit: search_result.result_limit,
        reconciliation_retry_count: attempt.reconciliation_retry_count,
        next_reconciliation_retry_at: attempt.next_reconciliation_retry_at
      }
    end

    def search_audit_metadata(search_result)
      result_attributes(search_result).merge(
        search_has_more_results: search_result.search_has_more_results
      )
    end

    def issue_draft
      @issue_draft ||= attempt.issue_draft
    end

    def project
      @project ||= attempt.project
    end

    def reconcile!(match, search_result)
      issue_draft.update!(
        status: "published",
        github_issue_number: match.fetch(:github_issue_number),
        github_issue_url: match.fetch(:github_issue_url),
        github_repository: match.fetch(:github_repository, attempt.github_repository),
        github_issue_api_id: match[:github_issue_api_id],
        github_issue_node_id: match[:github_issue_node_id],
        publish_error: nil
      )
      attempt.mark_reconciled!(match)
      resolve_review_blocker!
      AuditLog.record!(
        project: project,
        action: "issue_draft.github_publish_reconciled",
        target: issue_draft,
        summary: "GitHub Issue publish was reconciled from marker search.",
        metadata: audit_metadata(match).merge(attempt_id: attempt.id, match_count: 1).merge(search_audit_metadata(search_result))
      )

      Result.new(status: "reconciled", matches: [match], **result_attributes(search_result))
    end

    def block_for_human_review!(matches, search_result)
      code, detail = review_blocker_reason(matches, search_result)
      attempt.update!(
        status: "reconciliation_required",
        safe_error_code: code,
        safe_error_detail: detail,
        completed_at: Time.current
      )
      schedule_review_retry!(code)
      review = upsert_review_blocker!(code, detail, matches)
      AuditLog.record!(
        project: project,
        action: "issue_draft.github_publish_reconciliation_blocked",
        target: issue_draft,
        summary: "GitHub Issue publish reconciliation requires human review.",
        metadata: {
          attempt_id: attempt.id,
          match_count: matches.count,
          safe_error_code: code,
          review_id: review.id
        }.merge(search_audit_metadata(search_result))
      )

      Result.new(status: "review_required", matches: matches, review: review, **result_attributes(search_result))
    end

    def upsert_review_blocker!(code, detail, matches)
      review = active_review_blocker || Review.new(
        target_type: "issue_draft",
        target_id: issue_draft.id,
        reviewer_role: REVIEWER_ROLE
      )

      transition_service.mark_action_required!(
        review: review,
      reason_code: code,
      reason_text: detail,
      attributes: {
          framework: FRAMEWORK,
          positives: ["GitHub marker search ran before creating another Issue."],
          improvements: [detail, "Do not retry publish until a reviewer confirms the correct GitHub Issue state."],
          priority: ["P0: Resolve GitHub publish reconciliation before re-publishing."],
          next_actions: next_actions(code, matches),
          issue_numbers: ["ISSUE-004"],
          resolution_note: nil
      }
    )

      review
    end

    def resolve_review_blocker!
      review = active_review_blocker
      return unless review && review.status != "accepted_risk"

      transition_service.resolve!(
        review: review,
        resolution_note: "GitHub publish reconciliation resolved at #{Time.current.iso8601}.",
        reason_code: "github_reconciliation_resolved",
        issue_numbers: ["ISSUE-004"]
      )

      review.update!(
        framework: FRAMEWORK,
        positives: ["One GitHub Issue marker match was reconciled."],
        improvements: ["No active GitHub publish reconciliation blocker remains."],
        priority: ["P0: Keep publish reconciliation clear before implementation starts."],
        next_actions: ["Proceed with the reconciled GitHub Issue link."],
        issue_numbers: ["ISSUE-004"]
      )
    end

    def transition_service
      @transition_service ||= ReviewTransitionService.new(project: project, actor_id: "system", sensitive_handling: :redact)
    end

    def active_review_blocker
      @active_review_blocker ||= Review.where(
        target_type: "issue_draft",
        target_id: issue_draft.id,
        reviewer_role: REVIEWER_ROLE,
        status: "action_required"
      ).order(created_at: :desc).first
    end

    def next_actions(code, matches)
      if code == "github_publish_reconciliation_incomplete_results"
        actions = ["Wait for GitHub Search to settle, then rerun marker search once after the configured cooldown."]
        if matches.any?
          issue_numbers = matches.map { |match| "##{match.fetch(:github_issue_number)}" }.join(", ")
          actions << "Review visible candidate GitHub Issues before any manual link: #{issue_numbers}."
        end
        actions << "Do not approve controlled retry until GitHub Search is complete or a reviewer has manually confirmed no Issue exists."
        return actions
      end

      return ["Confirm whether the GitHub Issue was never created, then approve a controlled retry."] if matches.empty?

      issue_numbers = matches.map { |match| "##{match.fetch(:github_issue_number)}" }.join(", ")
      [
        "Review matching GitHub Issues: #{issue_numbers}.",
        "Choose the correct Issue manually or close duplicates before reconciling."
      ]
    end

    def audit_metadata(match)
      {
        github_issue_number: match.fetch(:github_issue_number),
        github_issue_url: match.fetch(:github_issue_url),
        github_repository: match.fetch(:github_repository, attempt.github_repository),
        github_issue_api_id: match[:github_issue_api_id],
        github_issue_node_id: match[:github_issue_node_id]
      }
    end

    def review_blocker_reason(matches, search_result)
      if search_result.incomplete_results
        return [
          "github_publish_reconciliation_incomplete_results",
          "GitHub marker search returned incomplete results."
        ]
      end

      if matches.empty?
        ["github_publish_reconciliation_no_match", "No GitHub Issue marker match was found."]
      else
        ["github_publish_reconciliation_multiple_matches", "Multiple GitHub Issue marker matches were found."]
      end
    end

    def schedule_review_retry!(code)
      return unless retryable_review_code?(code)

      schedule_retry!(available_at: Time.current + DEFAULT_RETRY_COOLDOWN)
    end

    def retryable_review_code?(code)
      %w[
        github_publish_reconciliation_incomplete_results
        github_publish_reconciliation_no_match
      ].include?(code)
    end

    def retryable_provider_error?(error)
      error.code == "github_issue_marker_search_rate_limited"
    end

    def retry_available_at(error)
      retry_after = error.safe_metadata[:github_retry_after_seconds].to_i
      retry_after = DEFAULT_RETRY_COOLDOWN.to_i if retry_after <= 0
      Time.current + retry_after.seconds
    end

    def schedule_retry!(available_at:)
      return unless attempt.schedule_reconciliation_retry!(available_at: available_at)

      ReconciliationRetryScheduler.call(attempt, available_at: attempt.next_reconciliation_retry_at)
    end
  end
end
