# ISSUE-032: Conversation Summary Draft JSON本文の保護方針を実装する

## Issue番号

ISSUE-032

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/32

登録日: 2026-07-05

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

## レビュー結果

ISSUE-029ではsummary draft JSON本文をretention/anonymizationで保護する初期方針にした。しかし、暗号化ではないため、保持期間中のDB漏えいリスクが残る。世界レベルSaaS基準では、AI生成物もセンシティブ派生データとして扱う必要がある。

## 優先度

P0

理由:

- AI整理結果にも個人情報や機密タスクが含まれる可能性がある
- raw/redacted textだけ暗号化しても派生データが残ると削除要求に弱い
- AI PM Platformの信頼性と監査性に直結する

## 次アクション

1. `conversation_summary_drafts` のschemaと利用箇所を確認する。
2. 暗号化、短期保持、匿名化強化の選択肢を比較する。
3. API影響とmigration方針をレビューする。
4. 採用方針に従って実装する。
