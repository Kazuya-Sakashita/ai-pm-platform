FactoryBot.define do
  factory :minute do
    meeting
    status { "generated" }
    summary { "Discussed MVP scope." }
    decisions { [{ "text" => "Ship the backend slice first." }] }
    open_questions { ["Who owns CI?"] }
    action_items { [{ "text" => "Add request specs.", "status" => "open" }] }
    generated_by_model { "deterministic-minutes-placeholder-v1" }
  end
end
