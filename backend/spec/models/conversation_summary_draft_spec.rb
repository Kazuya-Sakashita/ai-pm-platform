require "rails_helper"

RSpec.describe ConversationSummaryDraft, type: :model do
  it "encrypts protected payload even when assigned through low-level column updates" do
    draft = create(:conversation_summary_draft)
    sensitive_text = "migration backfill secret"
    payload = ConversationSummaryDraft::PROTECTED_PAYLOAD_DEFAULTS.transform_values do |value|
      value.is_a?(Array) ? [] : value
    end.merge(
      summary: sensitive_text,
      source_quotes: [{ id: "q1", quote: sensitive_text }]
    )

    draft.update_columns(protected_payload: JSON.generate(payload))

    stored_payload = ConversationSummaryDraft.connection.select_value(
      "SELECT protected_payload FROM conversation_summary_drafts WHERE id = #{ConversationSummaryDraft.connection.quote(draft.id)}"
    )
    expect(stored_payload).not_to include(sensitive_text)
    expect(draft.reload.summary).to eq(sensitive_text)
    expect(draft.source_quotes).to eq([{ "id" => "q1", "quote" => sensitive_text }])
  end
end
