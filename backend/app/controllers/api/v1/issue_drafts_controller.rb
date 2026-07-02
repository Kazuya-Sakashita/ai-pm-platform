module Api
  module V1
    class IssueDraftsController < ApplicationController
      def generate
        requirement = Requirement.find(params[:id])
        return render_review_required(requirement) unless requirement.status == "approved"

        job = project_for(requirement).jobs.create!(
          job_type: "ai_generation",
          status: "running",
          target_type: "issue_draft",
          progress: 10
        )

        issue_draft = IssueDraftGenerationService.new(requirement).call
        job.update!(
          status: "succeeded",
          target_id: issue_draft.id,
          progress: 100
        )

        AuditLog.record!(
          project: project_for(requirement),
          action: "issue_draft.generated",
          target: issue_draft,
          metadata: { requirement_id: requirement.id, job_id: job.id }
        )

        render json: { data: { job_id: job.id, status: job.status } }, status: :accepted
      rescue IssueDraftGeneration::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: project_for(requirement),
          action: "issue_draft.generation_failed",
          target: job,
          metadata: { requirement_id: requirement.id, provider_error_code: e.code }
        ) if job && requirement

        render_error(e.code, e.safe_detail, e.http_status, { job_id: job&.id }.compact)
      end

      def show
        render json: { data: issue_draft.api_json }
      end

      def update
        issue_draft.update!(issue_draft_params)
        AuditLog.record!(
          project: project_for(issue_draft.requirement),
          action: "issue_draft.updated",
          target: issue_draft
        )
        render json: { data: issue_draft.api_json }
      end

      def publish_github
        gate = IssueDraftPublishGate.new(issue_draft).call
        return render_publish_blocked(gate) unless gate.allowed

        job = project_for(issue_draft.requirement).jobs.create!(
          job_type: "github_publish",
          status: "running",
          target_type: "issue_draft",
          target_id: issue_draft.id,
          progress: 10
        )

        result = GithubIssuePublishService.new(
          issue_draft,
          idempotency_key: request.headers["Idempotency-Key"]
        ).call
        job.update!(status: "succeeded", progress: 100)

        AuditLog.record!(
          project: project_for(issue_draft.requirement),
          action: "issue_draft.github_published",
          target: issue_draft,
          metadata: {
            job_id: job.id,
            attempt_id: result[:attempt_id],
            github_issue_number: result[:github_issue_number],
            github_issue_url: result[:github_issue_url],
            openapi_draft_id: gate.details[:openapi_draft_id]
          }.compact
        )

        render json: { data: result }, status: :accepted
      rescue GithubIssuePublish::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: project_for(issue_draft.requirement),
          action: "issue_draft.github_publish_failed",
          target: issue_draft,
          metadata: github_provider_error_metadata(e, job_id: job&.id)
        )

        render_error(e.code, e.safe_detail, e.http_status, github_provider_error_metadata(e, job_id: job&.id))
      end

      def reconcile_github_publish
        attempt = latest_reconciliation_attempt
        return render_reconciliation_not_required unless attempt
        return render_reconciliation_cooldown(attempt) if attempt.reconciliation_cooldown_active?

        job = project_for(issue_draft.requirement).jobs.create!(
          job_type: "github_reconciliation",
          status: "running",
          target_type: "issue_draft",
          target_id: issue_draft.id,
          progress: 10
        )

        result = GithubIssuePublish::ReconciliationService.new(attempt).call
        job.update!(status: "succeeded", progress: 100)

        render json: { data: reconciliation_response(result, attempt, job) }, status: :accepted
      rescue GithubIssuePublish::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: project_for(issue_draft.requirement),
          action: "issue_draft.github_publish_reconciliation_failed",
          target: issue_draft,
          metadata: github_provider_error_metadata(e, reconciliation_cooldown_metadata(attempt).merge(job_id: job&.id, attempt_id: attempt&.id))
        )

        render_error(e.code, e.safe_detail, e.http_status, github_provider_error_metadata(e, reconciliation_cooldown_metadata(attempt).merge(job_id: job&.id, attempt_id: attempt&.id)))
      end

      def resolve_github_reconciliation
        attempt = reconciliation_attempt_for_manual_resolution
        return render_reconciliation_not_required unless attempt

        job = project_for(issue_draft.requirement).jobs.create!(
          job_type: "github_reconciliation",
          status: "running",
          target_type: "issue_draft",
          target_id: issue_draft.id,
          progress: 10
        )

        result = GithubIssuePublish::ManualReconciliationService.new(
          attempt,
          github_reconciliation_resolution_params,
          job: job
        ).call
        job.update!(status: "succeeded", progress: 100)

        render json: { data: manual_reconciliation_response(result, attempt, job) }, status: :accepted
      rescue GithubIssuePublish::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: project_for(issue_draft.requirement),
          action: "issue_draft.github_publish_manual_reconciliation_failed",
          target: issue_draft,
          metadata: github_provider_error_metadata(e, reconciliation_cooldown_metadata(attempt).merge(job_id: job&.id, attempt_id: attempt&.id))
        )

        render_error(e.code, e.safe_detail, e.http_status, github_provider_error_metadata(e, reconciliation_cooldown_metadata(attempt).merge(job_id: job&.id, attempt_id: attempt&.id)))
      end

      private

      def issue_draft
        @issue_draft ||= IssueDraft.find(params[:issue_draft_id] || params[:id])
      end

      def reconciliation_attempt_for_manual_resolution
        scope = issue_draft.github_issue_publish_attempts.where(status: "reconciliation_required")
        return scope.find_by(id: params[:attempt_id]) if params[:attempt_id].present?

        scope.order(created_at: :desc).first
      end

      def latest_reconciliation_attempt
        @latest_reconciliation_attempt ||= issue_draft.github_issue_publish_attempts
                                                      .where(status: "reconciliation_required")
                                                      .order(created_at: :desc)
                                                      .first
      end

      def render_reconciliation_not_required
        render_error(
          "github_publish_reconciliation_not_required",
          "No GitHub publish reconciliation attempt is pending.",
          :conflict,
          { issue_draft_id: issue_draft.id, issue_draft_status: issue_draft.status }
        )
      end

      def render_reconciliation_cooldown(attempt)
        render_error(
          "github_reconciliation_cooldown_active",
          "GitHub reconciliation retry is cooling down.",
          :conflict,
          reconciliation_cooldown_metadata(attempt)
        )
      end

      def render_review_required(requirement)
        render_error(
          "review_required",
          "Requirement must be approved before generating issue drafts.",
          :conflict,
          { requirement_id: requirement.id, status: requirement.status }
        )
      end

      def render_publish_blocked(gate)
        render_error(
          gate.code,
          gate.message,
          :conflict,
          gate.details
        )
      end

      def project_for(requirement)
        requirement.minute.meeting.project
      end

      def github_provider_error_metadata(error, extra = {})
        {
          provider_error_code: error.code
        }.merge(error.safe_metadata).merge(extra).compact
      end

      def reconciliation_cooldown_metadata(attempt)
        return {} unless attempt

        {
          attempt_id: attempt.id,
          reconciliation_retry_count: attempt.reconciliation_retry_count,
          next_reconciliation_retry_at: attempt.next_reconciliation_retry_at&.iso8601,
          reconciliation_cooldown_active: attempt.reconciliation_cooldown_active?
        }.compact
      end

      def reconciliation_response(result, attempt, job)
        {
          job_id: job.id,
          status: result.status,
          attempt_id: attempt.id,
          match_count: result.matches.count,
          search_total_count: result.search_total_count,
          search_incomplete_results: result.search_incomplete_results,
          search_result_limit: result.search_result_limit,
          search_has_more_results: result.search_has_more_results,
          reconciliation_retry_count: result.reconciliation_retry_count,
          next_reconciliation_retry_at: result.next_reconciliation_retry_at&.iso8601,
          reconciliation_cooldown_active: result.reconciliation_cooldown_active,
          review_id: result.review&.id,
          matches: reconciliation_matches(result.matches, attempt),
          github_issue_number: issue_draft.github_issue_number,
          github_issue_url: issue_draft.github_issue_url
        }.compact
      end

      def reconciliation_matches(matches, attempt)
        matches.map do |match|
          {
            github_issue_number: match.fetch(:github_issue_number),
            github_issue_url: match.fetch(:github_issue_url),
            github_repository: match.fetch(:github_repository, attempt.github_repository),
            github_issue_title: match[:github_issue_title],
            github_issue_state: match[:github_issue_state],
            github_issue_updated_at: match[:github_issue_updated_at],
            github_issue_score: match[:github_issue_score],
            github_issue_api_id: match[:github_issue_api_id],
            github_issue_node_id: match[:github_issue_node_id]
          }.compact
        end
      end

      def manual_reconciliation_response(result, attempt, job)
        {
          job_id: job.id,
          status: result.status,
          attempt_id: attempt.id,
          review_id: result.review&.id,
          github_issue_number: issue_draft.github_issue_number,
          github_issue_url: issue_draft.github_issue_url
        }.compact
      end

      def github_reconciliation_resolution_params
        params.permit(
          :resolution_action,
          :resolution_note,
          :github_issue_number,
          :github_issue_url,
          :github_issue_api_id,
          :github_issue_node_id
        )
      end

      def issue_draft_params
        params.permit(
          :title,
          :body,
          :status,
          acceptance_criteria: [],
          labels: []
        )
      end
    end
  end
end
