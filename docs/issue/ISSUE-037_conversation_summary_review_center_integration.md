# ISSUE-037: Review CenterとConversation Summary Draft承認を連動する

## Issue番号

ISSUE-037

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/37

登録日: 2026-07-05

## 背景

ISSUE-022のFrontend MVPでは、DM整理ドラフトをDM整理パネル内で承認できる。ただし、AI PM Platformの統制体験としては、会議、議事録、要件、Issue、OpenAPIと同じように、Review Centerでレビュー対象を一覧し、承認/差し戻し/ブロッカーを管理できる必要がある。

DM由来の整理結果はプライバシーと誤要約リスクが高いため、単一パネル内の承認だけでは監査、比較、レビュー履歴が弱い。

## 目的

Conversation Summary DraftをReview Centerの対象として扱い、レビュー依頼、レビュー結果表示、承認/差し戻し、次工程ブロッカーに接続する。

## 完了条件

- `conversation_summary_draft` target_typeのレビュー作成/一覧/表示がUIから扱える
- DM整理ドラフト承認前にレビュー状態を確認できる
- action_required / needs_revisionの場合に承認や下流連携を止める
- レビュー履歴がAuditLogまたはReview listで追える
- Playwrightでレビュー依頼、ブロック、承認可能状態を検証している
- レビュー結果が `docs/review/` に保存されている

## スコープ

- Review Center UI連動
- Reviews API利用
- Conversation Summary Draft用レビュー依頼
- ブロッカー表示
- E2E追加
- UXレビュー

## 非スコープ

- 認証ユーザー実装
- 外部AI複数レビュー実行
- Slack/Notion連携
- Structured Outputs provider実装

## 関連レビュー

- `docs/review/20260705_discord_dm_frontend_mvp_review.md`
- `docs/review/20260701_openapi_validation_review_gate_review.md`

## レビュー結果

Codex一次レビューでは、DM整理パネル内承認はMVPとして有効。ただしレビュー履歴、ブロッカー、次工程制御がReview Centerと分断されており、AI PMとしての統制力が不足している。

## 優先度

P1

理由:

- AI PMの差別化であるReviewOps体験に直結する
- #35 AI provider接続、#36編集UI、#29データ保護と並行して進められる
- 既存Reviews APIを再利用できる

## 次アクション

1. Reviews APIのtarget_type `conversation_summary_draft` 対応状況を確認する。
2. DM整理ドラフト向けレビュー依頼payloadを決める。
3. UI上のブロッカー表示と承認条件を設計する。
4. E2Eとレビュー保存を追加する。
