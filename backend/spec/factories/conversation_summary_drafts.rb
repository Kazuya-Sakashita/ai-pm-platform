FactoryBot.define do
  factory :conversation_summary_draft do
    conversation_import
    provider { "deterministic" }
    model { "deterministic-conversation-summary-v1" }
    status { "draft" }
    summary { "DM整理の要点をまとめる。" }
    decisions { [{ text: "手動貼り付けから始める", confidence: 0.7 }] }
    open_questions { ["自動取得の時期"] }
    action_items { [{ text: "同意確認を必須にする", status: "open", confidence: 0.6 }] }
    issue_candidates { [] }
    requirement_candidates { [] }
    risks { [] }
    participants { [{ display_name: "Kazuya", role: "requester" }] }
    source_quotes { [{ id: "q1", quote: "決定: 手動貼り付けから始める。" }] }
    confidence { 0.62 }
    generated_at { Time.current }
  end
end
