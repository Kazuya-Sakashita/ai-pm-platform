class AddProtectedPayloadToConversationSummaryDrafts < ActiveRecord::Migration[7.1]
  class ConversationSummaryDraftRecord < ActiveRecord::Base
    self.table_name = "conversation_summary_drafts"

    encrypts :protected_payload
  end

  STORED_SUMMARY_PLACEHOLDER = "暗号化済み".freeze
  ANONYMIZED_SUMMARY = "削除済み".freeze
  PROTECTED_ARRAY_FIELDS = %w[
    decisions
    open_questions
    action_items
    issue_candidates
    requirement_candidates
    risks
    participants
    source_quotes
    validation_errors
  ].freeze

  def up
    add_column :conversation_summary_drafts, :protected_payload, :text

    ConversationSummaryDraftRecord.reset_column_information
    ConversationSummaryDraftRecord.find_each do |draft|
      payload = {
        summary: draft.summary
      }
      PROTECTED_ARRAY_FIELDS.each do |field|
        payload[field] = draft.public_send(field) || []
      end

      sanitized_columns = {
        protected_payload: JSON.generate(payload),
        summary: STORED_SUMMARY_PLACEHOLDER
      }
      PROTECTED_ARRAY_FIELDS.each do |field|
        sanitized_columns[field] = []
      end

      draft.update_columns(sanitized_columns)
    end

    change_column_null :conversation_summary_drafts, :protected_payload, false
  end

  def down
    change_column_null :conversation_summary_drafts, :protected_payload, true

    ConversationSummaryDraftRecord.reset_column_information
    ConversationSummaryDraftRecord.find_each do |draft|
      payload = parse_payload(draft.protected_payload)
      restored_columns = {
        summary: payload.fetch("summary", ANONYMIZED_SUMMARY).presence || ANONYMIZED_SUMMARY
      }
      PROTECTED_ARRAY_FIELDS.each do |field|
        restored_columns[field] = payload.fetch(field, [])
      end

      draft.update_columns(restored_columns)
    end

    remove_column :conversation_summary_drafts, :protected_payload
  end

  private

  def parse_payload(value)
    return {} if value.blank?

    JSON.parse(value)
  rescue JSON::ParserError
    {}
  end
end
