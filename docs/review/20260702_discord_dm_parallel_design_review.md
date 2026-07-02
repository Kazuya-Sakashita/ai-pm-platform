# Discord DM Parallel Design Review

## 評価日時

2026-07-02 20:05:55 JST

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
- UI/UX Designer

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- DDD
- C4 Model
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010

## 対象

- Issue番号: #22
- 対象ファイル:
  - `docs/architecture/20260702_discord_dm_manual_import_db_design.md`
  - `docs/product/20260702_discord_dm_manual_import_screen_design.md`
  - `docs/ai/20260702_discord_dm_summary_prompt_schema.md`
  - `docs/issue/ISSUE-022_discord_dm_manual_import_mvp.md`

## 良かった点

- DB設計でraw text、redacted text、AI整理結果、revision、AuditLogの責任境界を分けた。
- 画面設計で同意確認、scan、redaction、AI整理、Review Gateを段階化した。
- AI prompt/schemaで推測禁止、根拠引用、confidence、secret非出力を明文化した。
- DM自動取得を避けるADR-0009と整合し、手動貼り付けMVPの安全性を補強した。
- Issue候補と要件候補をAI整理結果から直接公開せず、レビュー承認を必須にした。

## 改善点

- OpenAPI本体へのConversation Import schema追加は未実施。
- DB migration、model、controller、service実装は未着手。
- raw text暗号化方式と保持期間は未確定。
- redaction UXの具体的なUI componentとE2Eは未作成。
- AI schemaは設計案であり、OpenAI Structured Outputsへの実接続は未実装。
- 法務/運用観点での参加者同意文言レビューは未実施。

## 優先順位

- P0: OpenAPI本体へConversation Import / Summary Draft schemaとendpointを追加する。
- P0: DB設計をmigration可能な形へ落とし込む。
- P0: secret/PII scan blockerを既存Minutes生成のsecret scanと共通化する。
- P1: DMインポートUIのwireframeを実装前にPlaywright観点でレビューする。
- P1: AI prompt/schemaをStructured Outputs前提で実装可能なJSON schemaへ変換する。

## 次アクション

- OpenAPI draftを `docs/api/openapi.yaml` に反映し、`npm run api:verify` を通す。
- conversation_imports / conversation_summary_drafts のDB migration案を作る。
- DMインポートUIの静的画面またはワイヤーフレームを追加する。
- AI整理serviceのinterfaceとfailure contractを設計する。
- Issue #22をGitHubへ同期する。

## Issue番号

- #22

## レビュー結果

設計フェーズとして条件付き合格。DB、画面、AI prompt/schemaを並行して前進させたことで、実装前に主要なリスク境界が見えるようになった。ただし世界レベルのSaaS基準では、OpenAPI本体、DB migration、暗号化/保持期間、redaction UX、Structured Outputs接続、E2Eが未完了のため、実装へはまだ進めない。

## 検証結果

- ドキュメント追加のみ
- `git diff --check`: success
