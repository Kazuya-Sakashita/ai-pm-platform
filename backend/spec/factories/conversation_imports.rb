FactoryBot.define do
  factory :conversation_import do
    project
    source_type { "discord_dm_paste" }
    title { "Discord DM整理" }
    raw_text do
      <<~TEXT
        Kazuya: 決定: DM整理は手動貼り付けから始める。
        Reviewer: TODO: 同意確認とredactionを必須にする。
        Kazuya: 未決: 自動取得はいつ扱う？
      TEXT
    end
    participants { [{ display_name: "Kazuya", role: "requester" }] }
    consent_confirmed { true }
    consent_statement_version { "dm-consent-v1" }
    status { "draft" }
  end
end
