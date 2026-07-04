# ISSUE-029: Discord DM由来テキストの暗号化・保持期限・削除基盤を実装する

## Issue番号

ISSUE-029

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/29

登録日: 2026-07-05

## 背景

ISSUE-022でDiscord DM手動インポートBackend/Frontend MVPが進み、ユーザーはDM貼り付け、マスキング、安全チェック、AI整理ドラフト生成、承認を操作できるようになった。

一方で、現時点の `conversation_imports.raw_text` と `conversation_imports.redacted_text` はDB平文保存である。Discord DMは高センシティブデータであり、暗号化、保持期限、削除/匿名化、権限、監査がない状態ではproduction-readyではない。

## 目的

Discord DM由来テキストをproductionで扱うために、raw/redacted textの暗号化、retention、削除/匿名化、監査、権限境界を実装する。

## 完了条件

- `ADR-0012` に沿った暗号化方式が実装されている
- raw text / redacted textがDB dump単体で読めない
- raw text 30日以内、redacted text / AI整理ドラフト180日以内の既定保持期限がある
- DMインポート単位の削除/匿名化APIがOpenAPIに定義され、Backend実装されている
- 削除/匿名化後に本文がAPIレスポンス、AuditLog、Job logへ残らない
- retention jobがSolid Queueで実行できる
- project membership導入後のPolicy Object設計が残っている
- request specで暗号化、削除、retention、AuditLog safe metadataを検証している
- セキュリティレビューが `docs/review/` に保存されている

## スコープ

- raw_text / redacted_text暗号化
- 暗号鍵管理方針のADRまたは実装メモ
- retention policy
- DMインポート削除/匿名化API
- Solid Queue retention job
- AuditLog safe metadata検証
- request spec
- OpenAPI更新
- セキュリティレビュー

## 非スコープ

- Discord DM自動取得
- Slack DM対応
- 認証基盤全体の実装
- エンタープライズDLP連携
- ユーザーごとの法務同意ワークフロー

## 関連レビュー

- `docs/review/20260705_discord_dm_frontend_mvp_review.md`
- `docs/review/20260705_discord_dm_backend_mvp_review.md`

## 関連ADR

- `docs/decisions/ADR-0012_discord_dm_text_encryption_retention.md`
- `docs/decisions/ADR-0009_discord_dm_manual_import_first.md`

## レビュー結果

Codex一次レビューでは、ISSUE-022のFrontend MVPは条件付き合格。ただしDM由来テキストは高センシティブデータであり、暗号化、retention、削除/匿名化、project membership認可がない状態ではproduction-readyではない。世界レベルSaaS基準では本IssueをP0 production blockerとして扱う。

## 優先度

P0

理由:

- DM原文は漏洩時の影響が大きい
- 現在の平文保存MVPをproductionへ進める blocker
- AI PM Platformの信頼性と監査可能性の根幹に関わる

## 次アクション

1. OpenAPIへ削除/匿名化/retention endpointを追加する。
2. Railsの暗号化方式と鍵管理をADRまたは実装設計へ落とす。
3. Backend model/service/job/specを実装する。
4. Frontendで削除/匿名化導線とretention表示を追加する。
5. STRIDE/OWASPレビューを保存する。
