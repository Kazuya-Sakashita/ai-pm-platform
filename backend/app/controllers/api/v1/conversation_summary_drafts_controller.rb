module Api
  module V1
    class ConversationSummaryDraftsController < ApplicationController
      def show
        return unless authorize_conversation_import!(draft_project, :read)

        render json: { data: draft.api_json }
      end

      def update
        return unless authorize_conversation_import!(draft_project, :update_summary_draft)
        return unless ensure_draft_editable!
        return unless ensure_requested_status_editable!

        draft.update!(draft_params)
        AuditLog.record!(
          project: draft.conversation_import.project,
          action: "conversation_summary_draft.updated",
          target: draft,
          actor_id: current_actor_id
        )

        render json: { data: draft.api_json }
      end

      def approve
        return unless authorize_conversation_import!(draft_project, :approve_summary_draft)
        return unless ensure_draft_editable!

        unless params[:approval_note].present?
          return render_error("approval_note_required", "整理ドラフトの承認理由を入力してください。", :unprocessable_entity)
        end

        draft.update!(status: "approved", approved_at: Time.current)
        draft.conversation_import.update!(status: "approved", approved_at: Time.current)
        AuditLog.record!(
          project: draft.conversation_import.project,
          action: "conversation_summary_draft.approved",
          target: draft,
          actor_id: current_actor_id,
          metadata: {
            conversation_import_id: draft.conversation_import_id,
            approval_note_present: params[:approval_note].present?,
            generate_downstream_candidates: params.fetch(:generate_downstream_candidates, true)
          }
        )

        render json: { data: draft.api_json }
      end

      private

      def draft
        @draft ||= ConversationSummaryDraft.find(params[:conversation_summary_draft_id] || params[:id])
      end

      def draft_project
        @draft_project ||= draft.conversation_import.project
      end

      def draft_params
        params.permit(
          :summary,
          :status,
          decisions: [:text, :owner, :confidence, { source_quote_ids: [] }],
          open_questions: [],
          action_items: [:text, :owner, :due_date, :status, :confidence, { source_quote_ids: [] }],
          issue_candidates: [:title, :body, :priority, :confidence, { labels: [], source_quote_ids: [] }],
          requirement_candidates: [:title, :requirement, :confidence, { acceptance_criteria: [], source_quote_ids: [] }],
          risks: [:text, :severity, :mitigation, :confidence, { source_quote_ids: [] }],
          participants: [:display_name, :handle, :role, :notes]
        )
      end

      def ensure_draft_editable!
        return true if draft.editable?

        render_error(
          "summary_draft_not_editable",
          "承認済みまたは古い整理ドラフトは編集できません。",
          :unprocessable_entity,
          { status: draft.status, editable_statuses: ConversationSummaryDraft::EDITABLE_STATUSES }
        )
        false
      end

      def ensure_requested_status_editable!
        return true if params[:status].blank?
        return true if ConversationSummaryDraft::EDITABLE_STATUSES.include?(params[:status])

        render_error(
          "summary_draft_status_not_editable",
          "整理ドラフトの状態は編集可能な状態にのみ変更できます。",
          :unprocessable_entity,
          { requested_status: params[:status], editable_statuses: ConversationSummaryDraft::EDITABLE_STATUSES }
        )
        false
      end
    end
  end
end
