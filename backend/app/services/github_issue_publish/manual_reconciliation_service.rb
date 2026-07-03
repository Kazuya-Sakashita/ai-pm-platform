require "uri"

module GithubIssuePublish
  class ManualReconciliationService
    ACTIONS = %w[link_existing_issue approve_retry].freeze
    RESOLUTION_NOTE_MAX_LENGTH = 2000
    RETRY_APPROVER_MAX_LENGTH = 120
    RETRY_REASON_TEMPLATES = {
      "github_issue_absence_confirmed" => "GitHub上でIssue未作成を確認したため1回だけ再試行を承認します。",
      "github_search_complete_no_match" => "GitHub Search完了後も該当Issueがないため再試行を承認します。",
      "provider_transient_failure_confirmed" => "外部APIの一時的な失敗であり二重作成リスクが低いことを確認しました。"
    }.freeze
    REVIEWER_ROLE = ReconciliationService::REVIEWER_ROLE
    FRAMEWORK = ReconciliationService::FRAMEWORK
    Result = Struct.new(:status, :review, :resolution_approver, :retry_reason_template, keyword_init: true)

    def initialize(attempt, params, job: nil)
      @attempt = attempt
      @params = params.to_h.symbolize_keys
      @job = job
    end

    def call
      ensure_pending_attempt!
      ensure_action!
      ensure_resolution_note!
      ensure_retry_approval_metadata! if action == "approve_retry"
      ensure_retry_cooldown_elapsed! if action == "approve_retry"

      return link_existing_issue! if action == "link_existing_issue"
      return approve_retry! if action == "approve_retry"

      raise_manual_error(
        "github_reconciliation_action_invalid",
        "GitHub reconciliation action is invalid.",
        :unprocessable_entity
      )
    end

    private

    attr_reader :attempt, :params, :job

    def issue_draft
      @issue_draft ||= attempt.issue_draft
    end

    def project
      @project ||= attempt.project
    end

    def action
      params[:resolution_action].to_s
    end

    def resolution_note
      params[:resolution_note].to_s.strip
    end

    def resolution_approver
      params[:resolution_approver].to_s.strip
    end

    def retry_reason_template
      params[:retry_reason_template].to_s.strip
    end

    def ensure_pending_attempt!
      return if attempt.status == "reconciliation_required"

      raise_manual_error(
        "github_reconciliation_attempt_not_pending",
        "GitHub publish reconciliation attempt is not pending.",
        :conflict
      )
    end

    def ensure_action!
      return if ACTIONS.include?(action)

      raise_manual_error(
        "github_reconciliation_action_required",
        "A valid GitHub reconciliation action is required.",
        :unprocessable_entity
      )
    end

    def ensure_resolution_note!
      if resolution_note.blank?
        raise_manual_error(
          "github_reconciliation_resolution_note_required",
          "A resolution note is required for manual GitHub reconciliation.",
          :unprocessable_entity
        )
      end

      return unless resolution_note.length > RESOLUTION_NOTE_MAX_LENGTH

      raise_manual_error(
        "github_reconciliation_resolution_note_too_long",
        "Resolution note is too long for manual GitHub reconciliation.",
        :unprocessable_entity
      )
    end

    def ensure_retry_approval_metadata!
      if resolution_approver.blank?
        raise_manual_error(
          "github_reconciliation_retry_approver_required",
          "A retry approver is required for controlled GitHub publish retry.",
          :unprocessable_entity
        )
      end

      if resolution_approver.length > RETRY_APPROVER_MAX_LENGTH
        raise_manual_error(
          "github_reconciliation_retry_approver_too_long",
          "Retry approver is too long for controlled GitHub publish retry.",
          :unprocessable_entity
        )
      end

      if retry_reason_template.blank?
        raise_manual_error(
          "github_reconciliation_retry_reason_template_required",
          "A retry reason template is required for controlled GitHub publish retry.",
          :unprocessable_entity
        )
      end

      return if RETRY_REASON_TEMPLATES.key?(retry_reason_template)

      raise_manual_error(
        "github_reconciliation_retry_reason_template_invalid",
        "Retry reason template is invalid for controlled GitHub publish retry.",
        :unprocessable_entity
      )
    end

    def ensure_retry_cooldown_elapsed!
      return unless attempt.reconciliation_cooldown_active?

      raise ProviderError.new(
        code: "github_reconciliation_cooldown_active",
        message: "GitHub reconciliation retry is cooling down.",
        safe_detail: "GitHub reconciliation retry is cooling down.",
        http_status: :conflict,
        safe_metadata: {
          reconciliation_retry_count: attempt.reconciliation_retry_count,
          next_reconciliation_retry_at: attempt.next_reconciliation_retry_at&.iso8601,
          reconciliation_cooldown_active: true
        }.compact
      )
    end

    def link_existing_issue!
      match = manual_match
      issue_draft.update!(
        status: "published",
        github_issue_number: match.fetch(:github_issue_number),
        github_issue_url: match.fetch(:github_issue_url),
        github_repository: match.fetch(:github_repository),
        github_issue_api_id: match[:github_issue_api_id],
        github_issue_node_id: match[:github_issue_node_id],
        publish_error: nil
      )
      attempt.mark_reconciled!(match)
      review = resolve_review_blocker!("Manual GitHub Issue link accepted at #{Time.current.iso8601}. #{resolution_note}")
      AuditLog.record!(
        project: project,
        action: "issue_draft.github_publish_manually_reconciled",
        target: issue_draft,
        summary: "GitHub Issue publish was manually reconciled.",
        metadata: audit_metadata(match).merge(
          attempt_id: attempt.id,
          job_id: job&.id,
          resolution_note: resolution_note
        ).compact
      )

      Result.new(status: "manually_reconciled", review: review)
    end

    def approve_retry!
      attempt.mark_retry_approved!(
        detail: "Controlled retry approved by #{resolution_approver}. #{retry_reason_label} #{resolution_note}"
      )
      issue_draft.update!(
        status: "approved",
        publish_error: nil
      )
      review = resolve_review_blocker!(
        "Controlled retry approved at #{Time.current.iso8601} by #{resolution_approver}. #{retry_reason_label} #{resolution_note}"
      )
      AuditLog.record!(
        project: project,
        action: "issue_draft.github_publish_retry_approved",
        target: issue_draft,
        summary: "GitHub Issue publish controlled retry was approved.",
        metadata: {
          attempt_id: attempt.id,
          job_id: job&.id,
          resolution_note: resolution_note,
          resolution_approver: resolution_approver,
          retry_reason_template: retry_reason_template,
          retry_reason_template_label: retry_reason_label
        }.compact
      )

      Result.new(
        status: "retry_approved",
        review: review,
        resolution_approver: resolution_approver,
        retry_reason_template: retry_reason_template
      )
    end

    def retry_reason_label
      RETRY_REASON_TEMPLATES.fetch(retry_reason_template)
    end

    def manual_match
      number = Integer(params[:github_issue_number])
      url = params[:github_issue_url].to_s.strip
      validate_github_issue_url!(url, number)

      {
        github_issue_number: number,
        github_issue_url: url,
        github_repository: project.github_repo,
        github_issue_api_id: params[:github_issue_api_id],
        github_issue_node_id: params[:github_issue_node_id].presence
      }
    rescue ArgumentError, TypeError
      raise_manual_error(
        "github_reconciliation_issue_number_invalid",
        "GitHub issue number must be a valid integer.",
        :unprocessable_entity
      )
    end

    def validate_github_issue_url!(url, number)
      uri = URI.parse(url)
      raise URI::InvalidURIError unless uri.scheme == "https" && uri.host == "github.com"

      owner, repository, resource, issue_number = uri.path.delete_prefix("/").split("/", 4)
      expected_owner, expected_repository = project.github_repo.to_s.split("/", 2)
      valid_repository = owner.to_s.casecmp?(expected_owner.to_s) &&
                         repository.to_s.casecmp?(expected_repository.to_s)
      valid_issue = resource == "issues" && issue_number.to_i == number && issue_number.to_s == number.to_s
      return if valid_repository && valid_issue

      raise URI::InvalidURIError
    rescue URI::InvalidURIError
      raise_manual_error(
        "github_reconciliation_issue_url_invalid",
        "GitHub issue URL must match the project repository and issue number.",
        :unprocessable_entity
      )
    end

    def resolve_review_blocker!(note)
      review = active_review_blocker
      return unless review && review.status != "accepted_risk"

      review.update!(
        status: "resolved",
        framework: FRAMEWORK,
        positives: ["Manual GitHub publish reconciliation was reviewed."],
        improvements: ["No active GitHub publish reconciliation blocker remains."],
        priority: ["P0: Keep manual reconciliation audit trail attached to the Issue Draft."],
        next_actions: ["Proceed according to the selected manual reconciliation action."],
        issue_numbers: ["ISSUE-004"],
        resolution_note: note
      )

      review
    end

    def active_review_blocker
      @active_review_blocker ||= Review.where(
        target_type: "issue_draft",
        target_id: issue_draft.id,
        reviewer_role: REVIEWER_ROLE,
        status: "action_required"
      ).order(created_at: :desc).first
    end

    def audit_metadata(match)
      {
        github_issue_number: match.fetch(:github_issue_number),
        github_issue_url: match.fetch(:github_issue_url),
        github_repository: match.fetch(:github_repository),
        github_issue_api_id: match[:github_issue_api_id],
        github_issue_node_id: match[:github_issue_node_id]
      }
    end

    def raise_manual_error(code, safe_detail, http_status)
      raise ProviderError.new(
        code: code,
        message: safe_detail,
        safe_detail: safe_detail,
        http_status: http_status
      )
    end
  end
end
