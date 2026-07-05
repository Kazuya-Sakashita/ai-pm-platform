# ISSUE-032: Conversation Summary Draft JSON本文の保護方針を実装する

## Issue番号

ISSUE-032

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/32

登録日: 2026-07-05

クローズ日: 2026-07-05

クローズ同期コメント: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/32#issuecomment-4884385287

## 背景

ISSUE-029ではDMインポートの `raw_text` / `redacted_text` を暗号化し、summary draftはretention/anonymizationの対象にした。一方で、`conversation_summary_drafts` のJSON本文にはDM由来の整理候補や要約情報が含まれる可能性がある。

現在の方針では180日匿名化までの間、summary draft JSON本文の暗号化可否が未検証である。AI整理結果は原文より加工済みでも、個人情報、機密、タスク背景を含み得るため、データ保護方針を明確化する必要がある。

## 目的

Conversation Summary Draft JSON本文を暗号化、短期保持、分離保存、または匿名化強化のいずれかで保護し、DM由来データの漏えいリスクを下げる。

## 完了条件

- summary draft JSON本文のデータ分類が `docs/security/` に保存されている
- 暗号化可否、検索要件、schema互換性、パフォーマンスの検証結果が保存されている
- 採用方針がADRまたは設計メモとして保存されている
- 必要に応じてOpenAPI/Backend migration/modelが更新されている
- request specでDB dump単体または匿名化後レスポンスにセンシティブ本文が残らないことを検証している
- ISSUE-029へ結果を同期している

## スコープ

- `conversation_summary_drafts` のデータ分類
- JSON本文暗号化または保持期限短縮の設計
- migration/model/service/spec
- OpenAPI更新が必要な場合の契約修正
- セキュリティレビュー

## 非スコープ

- AI生成品質改善
- 要件定義Draft全体の再設計
- 企業横断DLP
- 外部ベクトルDB連携

## 関連レビュー

- `docs/review/20260705_discord_dm_retention_delete_api_design_review.md`
- `docs/review/20260705_discord_dm_retention_delete_implementation_review.md`
- `docs/review/20260705_conversation_summary_draft_data_protection_design_review.md`
- `docs/review/20260705_conversation_summary_draft_data_protection_implementation_review.md`

## 関連ADR / Security Doc

- `docs/decisions/ADR-0014_conversation_summary_draft_protected_payload.md`
- `docs/security/20260705_conversation_summary_draft_data_classification.md`

## レビュー結果

ISSUE-029ではsummary draft JSON本文をretention/anonymizationで保護する初期方針にした。しかし、暗号化ではないため、保持期間中のDB漏えいリスクが残る。世界レベルSaaS基準では、AI生成物もセンシティブ派生データとして扱う必要がある。

2026-07-05に設計レビューを実施。`conversation_summary_drafts` の `summary`、候補JSON、`participants`、`source_quotes`、`validation_errors` を **Confidential / Derived Sensitive Data** と分類した。JSONB列への直接暗号化は採用せず、API互換を維持したままActive Record Encryptionの非決定性暗号化payloadへ集約する方針をADR-0014として採用した。

2026-07-05に実装完了。`protected_payload` migration、`ConversationSummaryDraft` accessor、request/model specを追加した。旧 `summary` / JSONB列は互換用に残し、保存時は `暗号化済み` と空配列へ無害化する。DB保存値、匿名化後レスポンス、low-level update経路の暗号化をspecで検証済み。

検証結果:

- `bundle exec rails db:migrate`: success
- `bundle exec rspec spec/models/conversation_summary_draft_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb spec/requests/api/v1/conversation_imports_spec.rb`: 17 examples, 0 failures
- `bundle exec rspec`: 170 examples, 0 failures
- `npm run api:verify`: success
- GitHub Actions CI `28725428860`: success（commit `0546ca6`）

補足: `npm run api:verify` では Node `v22.7.0` が期待範囲より古い警告が出たが、OpenAPI lint/type生成は成功した。

## 優先度

P0

理由:

- AI整理結果にも個人情報や機密タスクが含まれる可能性がある
- raw/redacted textだけ暗号化しても派生データが残ると削除要求に弱い
- AI PM Platformの信頼性と監査性に直結する

## 次アクション

1. 次の推奨順としてISSUE-030のProject membership/Policy Objectへ進む。
2. KMS/backup restoreの実運用証跡はISSUE-031系の継続運用で確認する。
3. summary draft検索要件が出たら、安全な派生index方針を別Issue化する。
