module Api
  module V1
    class ConversationImportsController < ApplicationController
      def index
        return unless authorize_conversation_import!(project, :read)

        imports = project.conversation_imports.order(created_at: :desc)
        render json: { data: imports.map(&:api_json), meta: pagination_meta(imports) }
      end

      def create
        return unless authorize_conversation_import!(project, :create)

        conversation_import = project.conversation_imports.create!(conversation_import_params)
        AuditLog.record!(
          project: project,
          action: "conversation_import.created",
          target: conversation_import,
          actor_id: current_actor_id,
          metadata: { source_type: conversation_import.source_type, consent_confirmed: conversation_import.consent_confirmed }
        )

        render json: { data: conversation_import.api_json }, status: :created
      end

      def show
        return unless authorize_conversation_import!(conversation_import.project, :read)

        render json: { data: conversation_import.api_json }
      end

      def update
        return unless authorize_conversation_import!(conversation_import.project, :update)
        return render_anonymized_error if conversation_import.anonymized_at?

        raw_text_changed = update_changes_summary_draft?
        conversation_import.update!(conversation_import_params)
        reset_scan_after_text_change! if raw_text_changed
        AuditLog.record!(
          project: conversation_import.project,
          action: "conversation_import.updated",
          target: conversation_import,
          actor_id: current_actor_id,
          metadata: { stale_summary_drafts: raw_text_changed }
        )

        render json: { data: conversation_import.api_json }
      end

      def destroy
        return unless authorize_conversation_import!(conversation_import.project, :anonymize)

        ConversationImports::RetentionService.new.anonymize!(
          conversation_import,
          reason: "manual_delete",
          actor_id: current_actor_id
        )
        head :no_content
      end

      def scan
        return unless authorize_conversation_import!(conversation_import.project, :scan)
        return render_anonymized_error if conversation_import.anonymized_at?

        result = ConversationImports::ScanService.new(conversation_import, actor_id: current_actor_id).call
        render json: {
          data: {
            valid: result.valid,
            conversation_import: result.conversation_import.api_json,
            safety_flags: result.safety_flags,
            blocked_reasons: result.blocked_reasons,
            redaction_suggestions: result.redaction_suggestions,
            next_action: result.next_action
          }
        }
      end

      def generate_summary
        return unless authorize_conversation_import!(conversation_import.project, :generate_summary)
        return render_anonymized_error if conversation_import.anonymized_at?

        job = conversation_import.project.jobs.create!(
          job_type: "ai_generation",
          status: "running",
          target_type: "conversation_summary_draft",
          progress: 10
        )

        draft = ConversationSummaryGenerationService.new(conversation_import).call
        job.update!(status: "succeeded", target_id: draft.id, progress: 100)
        AuditLog.record!(
          project: conversation_import.project,
          action: "conversation_summary_draft.generated",
          target: draft,
          actor_id: current_actor_id,
          metadata: { conversation_import_id: conversation_import.id, job_id: job.id }
        )

        render json: { data: { job: job.api_json, conversation_summary_draft: draft.api_json } }, status: :accepted
      rescue ConversationSummaryGeneration::ProviderError => e
        job&.update!(
          status: "failed",
          progress: 100,
          error_code: e.code,
          error_message: e.message,
          safe_error_detail: e.safe_detail
        )
        AuditLog.record!(
          project: conversation_import.project,
          action: "conversation_summary_draft.generation_failed",
          target: job,
          actor_id: current_actor_id || "system",
          metadata: { conversation_import_id: conversation_import.id, provider_error_code: e.code, request_id: e.request_id }.compact
        ) if job

        render_error(e.code, e.safe_detail, e.http_status, { job_id: job&.id, request_id: e.request_id }.compact)
      end

      private

      def project
        @project ||= Project.find(params[:project_id])
      end

      def conversation_import
        @conversation_import ||= ConversationImport.find(params[:conversation_import_id] || params[:id])
      end

      def conversation_import_params
        params.permit(
          :source_type,
          :title,
          :raw_text,
          :redacted_text,
          :conversation_started_at,
          :conversation_ended_at,
          :consent_confirmed,
          :consent_statement_version,
          participants: [:display_name, :handle, :role, :notes]
        )
      end

      def update_changes_summary_draft?
        params.key?(:raw_text) || params.key?(:redacted_text)
      end

      def stale_summary_drafts!
        conversation_import.conversation_summary_drafts.where.not(status: %w[approved rejected]).update_all(status: "stale", updated_at: Time.current)
      end

      def reset_scan_after_text_change!
        stale_summary_drafts!
        conversation_import.update!(
          status: "draft",
          safety_flags: [],
          blocked_reasons: [],
          last_scanned_at: nil
        )
      end

      def render_anonymized_error
        render_error(
          "conversation_import_anonymized",
          "Conversation import has been anonymized.",
          :unprocessable_entity
        )
      end
    end
  end
end
