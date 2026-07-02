# Discord DM Manual Import Requirements Review

## 評価日時

2026-07-02 19:15:23 JST

## 評価担当

- Codex
- Product Owner
- Product Manager
- CTO
- Tech Lead
- AI Architect
- Backend Architect
- Frontend Architect
- Security Engineer
- QA
- UI/UX Designer
- Business Consultant

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- MoSCoW
- STRIDE
- OWASP Top 10
- ISO25010
- HEART
- RICE

## 対象

- Issue番号: #22
- 対象ファイル:
  - `docs/issue/ISSUE-022_discord_dm_manual_import_mvp.md`
  - `docs/product/20260702_discord_dm_manual_import_requirements.md`
  - `docs/api/20260702_discord_dm_manual_import_api_design.md`
  - `docs/security/20260702_discord_dm_manual_import_security.md`
  - `docs/decisions/ADR-0009_discord_dm_manual_import_first.md`

## 良かった点

- Discord DM整理をIssue #2の会議ログ取り込みから分離し、データ感度と同意要件の違いを明確にした。
- MVPを手動貼り付けに絞り、Discord API制約、self-botリスク、未承認scopeリスクを避けた。
- 同意確認、redaction、secret/PII scan、review gate、AuditLogをP0要件に含めた。
- AI整理結果をsummaryだけでなく、decisions、open_questions、action_items、issue_candidates、requirement_candidates、risksへ分けた。
- ADRで「自動DM取得から始めない」判断を記録した。
- API設計でConversationImportとConversationSummaryDraftを分離し、raw textとAI整理結果の責任境界を置いた。

## 改善点

- OpenAPI本体への反映は未実施。
- DB設計がまだなく、raw text暗号化、revision、保持期間の設計が未確定。
- UI設計がまだなく、同意確認やredaction UXの摩擦が評価できない。
- AI prompt/schemaが未作成で、発言者取り違え、引用根拠、confidenceの品質基準が未定義。
- 参加者同意をプロダクト上どこまで担保するか、法務/運用観点の検討が不足している。
- live Discord API連携を将来検討する場合の審査・scope方針は未整理。

## 優先順位

- P0: OpenAPI draftへConversation Import APIを追加し、レビューする。
- P0: DB設計でraw/redacted text、revision、retention、AuditLogを定義する。
- P0: secret/PII scanとAI送信blockerの仕様を定義する。
- P1: DMインポートUIの画面設計と同意/redaction UXを作る。
- P1: AI整理prompt/schemaを `docs/ai/` に追加する。
- P2: 将来のDiscord公式連携、Bot DM、approved partner scopeの調査を分離Issue化する。

## 次アクション

- GitHub Issue #22として登録する。
- OpenAPI draftを作成する。
- DB設計レビューを作成する。
- DMインポートUI設計を作成する。
- AI prompt/schemaと安全評価基準を作成する。

## Issue番号

- #22

## レビュー結果

要件定義フェーズとして条件付き合格。DM整理はAI PM Platformの差別化に効くが、DMは高センシティブ情報であり、自動取得から始めるのは危険である。手動貼り付け、同意確認、redaction、secret scan、review gateをMVP必須条件にした判断は妥当。ただし、OpenAPI、DB設計、UI設計、AI prompt/schema、保持/削除方針が未完成のため、実装へはまだ進めない。

## 検証結果

- ドキュメント追加のみ
- `git diff --check`: success
