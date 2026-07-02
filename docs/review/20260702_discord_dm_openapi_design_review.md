# Discord DM OpenAPI Design Review

## 評価日時

2026-07-02 20:20:01 JST

## 評価担当

- Codex
- Product Manager
- CTO
- Tech Lead
- AI Architect
- Backend Architect
- Frontend Architect
- Security Engineer
- QA

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- DDD
- C4 Model
- STRIDE
- OWASP Top 10
- ISO25010

## 対象

- Issue番号: #22
- 対象ファイル:
  - `docs/api/openapi.yaml`
  - `frontend/lib/api/schema.d.ts`
  - `docs/api/20260702_discord_dm_manual_import_api_design.md`
  - `docs/issue/ISSUE-022_discord_dm_manual_import_mvp.md`

## 良かった点

- `ConversationImport` と `ConversationSummaryDraft` をOpenAPI本体へ追加し、Backend/Frontend実装前の契約を明確化した。
- 作成、取得、更新、scan、AI整理生成、整理ドラフト更新、承認のAPI境界を分けた。
- 同意確認、redaction、safety flags、blocked reasons、source quotes、confidenceをschemaに含め、DM由来データの監査性を高めた。
- `generate-summary` と `approve` に `Idempotency-Key` を付け、二重実行リスクを下げた。
- レビュー対象型に `conversation_import` と `conversation_summary_draft` を追加し、レビューゲートへ接続しやすくした。
- `npm run api:verify` によりOpenAPI lintとTypeScript schema生成が成功した。

## 改善点

- OpenAPI契約は追加済みだが、Backendのroute、controller、model、migration、serviceは未実装。
- `consent_confirmed=false` の保存可否、AI実行不可のエラーコード、UI文言の最終仕様が未確定。
- raw text / redacted text の暗号化、保持期間、削除、export方針はAPI契約だけでは不足している。
- scanの検出ロジック、共通secret/PII scannerとの統合、false positive訂正フローが未実装。
- `latest_summary_draft` をimportレスポンスへ含めるため、実装時にN+1や過剰な機微情報返却を防ぐ必要がある。
- AI整理ドラフト承認後にRequirement/Issue候補へどう接続するかは、後続APIでさらに詰める必要がある。

## 優先順位

- P0: conversation_imports / conversation_summary_drafts のDB migrationとmodelを追加する。
- P0: raw text / redacted text の暗号化、監査ログ、保持期間の実装方針をADRまたはsecurity docへ追記する。
- P0: scan blockerを通過しない限り `generate-summary` を実行できないBackend guardを実装する。
- P1: DMインポートUIを作り、同意、redaction、scan、AI整理、承認の導線をPlaywrightで検証する。
- P1: OpenAI Structured Outputs用のJSON schemaとservice failure contractを実装する。

## 次アクション

- DB設計をmigration可能な形へ落とし込み、model validationとrequest specを追加する。
- `ConversationImportsController` とscan/generate/approveの最小APIを実装する。
- secret/PII scanを既存のAI生成前チェックと共通化する。
- UI実装前に同意文言とredaction UXを再レビューする。
- Issue #22をGitHubへ同期し、OpenAPI契約完了を記録する。

## Issue番号

- #22

## レビュー結果

OpenAPI設計フェーズとして合格。ただし世界レベルのSaaS基準では、API契約が通っただけでは完成ではない。DMは会議ログよりセンシティブなため、Backend guard、暗号化、保持期間、監査、UI同意文言、AI送信前scanが実装されるまで、ユーザー向けMVPとしては未完成と判断する。

## 検証結果

- `npm run api:verify`: success
- `git diff --check`: success
