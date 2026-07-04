module Api
  module V1
    class ConversationSummaryDraftsController < ApplicationController
      def show
        render json: { data: draft.api_json }
      end

      def update
        draft.update!(draft_params)
        AuditLog.record!(
          project: draft.conversation_import.project,
          action: "conversation_summary_draft.updated",
          target: draft
        )

        render json: { data: draft.api_json }
      end

      def approve
        unless params[:approval_note].present?
          return render_error("approval_note_required", "整理ドラフトの承認理由を入力してください。", :unprocessable_entity)
        end

        draft.update!(status: "approved", approved_at: Time.current)
        draft.conversation_import.update!(status: "approved", approved_at: Time.current)
        AuditLog.record!(
          project: draft.conversation_import.project,
          action: "conversation_summary_draft.approved",
          target: draft,
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
    end
  end
end
