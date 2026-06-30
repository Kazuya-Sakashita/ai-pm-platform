FactoryBot.define do
  factory :requirement do
    minute { association :minute, status: "approved" }
    status { "generated" }
    background { "議事録サマリー: Discussed MVP scope." }
    goal { "会議で合意した内容を実装可能な成果物にする。" }
    user_stories { ["As a project member, I want reviewed requirements so that implementation can start."] }
    functional_requirements { ["FR-001: Generate requirement drafts from approved minutes."] }
    non_functional_requirements { ["レビュー結果を監査できること。"] }
    acceptance_criteria { ["Given approved minutes, when requirements are generated, then editable requirements are stored."] }
    out_of_scope { ["完全自動承認。"] }
    open_questions { ["Who owns final approval?"] }
    risks { ["AI生成内容は人間レビュー前提。"] }
    generated_by_model { "deterministic-requirements-placeholder-v1" }
  end
end
