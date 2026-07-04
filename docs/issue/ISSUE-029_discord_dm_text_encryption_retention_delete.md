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
- `docs/review/20260705_discord_dm_retention_delete_api_design_review.md`
- `docs/review/20260705_discord_dm_retention_delete_implementation_review.md`

## 関連ADR

- `docs/decisions/ADR-0012_discord_dm_text_encryption_retention.md`
- `docs/decisions/ADR-0009_discord_dm_manual_import_first.md`

## レビュー結果

Codex一次レビューでは、ISSUE-022のFrontend MVPは条件付き合格。ただしDM由来テキストは高センシティブデータであり、暗号化、retention、削除/匿名化、project membership認可がない状態ではproduction-readyではない。世界レベルSaaS基準では本IssueをP0 production blockerとして扱う。

2026-07-05にAPI設計レビューを実施。`DELETE /conversation-imports/{conversation_import_id}` は物理削除ではなく匿名化として定義し、AuditLogの追跡可能性と本文削除を両立する方針にした。raw textは30日、redacted text / AI整理ドラフトは180日の二段保持期限とする。

2026-07-05に初期実装sliceを追加。Active Record Encryptionで `raw_text` / `redacted_text` を暗号化し、保持期限timestamp、匿名化API、retention service/job、Frontend匿名化導線、request spec、Playwright E2Eを追加した。

2026-07-05に残P0/P1を個別Issueへ分割した。権限境界はISSUE-030、鍵管理とbackup削除方針はISSUE-031、AI整理draft JSON保護はISSUE-032、retention worker smokeはISSUE-033、Frontend失敗系E2EはISSUE-034で追跡する。

2026-07-05にISSUE-031でADR-0013とsecurity checklistを作成した。key rotation、KMS、backup削除方針は文書化済みだが、KMS provider選定、staging rotation smoke、backup retention provider設定、restore runbook反映は継続課題である。

2026-07-05にISSUE-033でretention worker smoke runbookを更新した。`ConversationImportRetentionJob`、Queue health API/UI確認、restore後retention/anonymization replayをstaging/production worker smoke手順へ追加した。GitHub #33はクローズ済み。実staging/prod実行証跡は環境未提供のため未取得。

2026-07-05にISSUE-034でFrontend失敗系E2Eを追加した。confirm cancel時のDELETE未実行、API 500/403/422のsafe Japanese error、失敗時の一覧保持、390px mobile幅のaudit non-overlapを確認した。GitHub #34はクローズ済み。実Backendの403 Policy ObjectはISSUE-030で継続する。

良かった点:

- DB dump単体でraw/redacted textを読めない状態へ前進した。
- productionで暗号化key未設定をboot blockerにした。
- 手動匿名化と期限切れretention jobが同じServiceを使う設計にした。
- AuditLogに本文やsecret値を保存しないspecを追加した。
- Frontendで保持期限と匿名化操作を確認できるようにした。

改善点:

- project membership認可と実ユーザーactorは未実装。
- KMS provider選定、staging rotation smoke、backup retention provider設定は未完了。
- `conversation_summary_drafts` のJSON本文は暗号化ではなくretention/anonymizationで保護している。
- 実Backendのproject membership認可と403応答は未実装。

検証結果:

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/requests/api/v1/conversation_imports_spec.rb`: 10 examples, 0 failures
- `bundle exec rspec`: 167 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts --grep "imports, scans"`: 1 passed
- GitHub Actions CI `28720456954`: success（commit `244b376`）
- GitHub Issue同期コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/29#issuecomment-4883892052`
- 残P0/P1分割コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/29#issuecomment-4883908857`
- ISSUE-034完了同期コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/29#issuecomment-4884039933`

## 優先度

P0

理由:

- DM原文は漏洩時の影響が大きい
- 現在の平文保存MVPをproductionへ進める blocker
- AI PM Platformの信頼性と監査可能性の根幹に関わる

## 次アクション

1. ISSUE-030でproject membership/Policy Objectを設計・実装する。
2. ISSUE-031でkey rotation、KMS、backup削除方針ADRを追加する（2026-07-05完了、GitHub #31クローズ済み）。
3. ISSUE-032でsummary draft JSON本文の暗号化可否を検証する。
4. ISSUE-033でretention jobをstaging worker smoke runbookへ追加する（2026-07-05完了、GitHub #33クローズ済み。実staging/prod証跡は未取得）。
5. ISSUE-034でFrontendの匿名化失敗、キャンセル、権限エラー、モバイル表示E2Eを追加する（2026-07-05完了、GitHub #34クローズ済み）。
