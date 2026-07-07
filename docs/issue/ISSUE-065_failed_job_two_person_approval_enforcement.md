# ISSUE-065: failed job discardの二人承認をDB/APIで強制する

## Issue番号

ISSUE-065

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/100

## 背景

ISSUE-063ではdiscardに二人承認またはrelease owner承認が必要である方針をQueue healthに表示した。しかし、現時点ではAPIが二人承認状態をDBで保持しておらず、実操作を機械的にブロックできない。

## 目的

高リスクdiscardを単独operatorのUI確認だけで実行できる状態から、監査可能な二人承認またはrelease owner承認へ引き上げる。

## 完了条件

- approval request/approval eventのDB設計がADRまたは設計レビューに残っている
- discard実行前に二人承認またはrelease owner承認をAPIで検証できる
- 同一actorによる申請と承認の兼任を禁止する
- 期限切れ承認、Project不一致、権限不足を安全に拒否する
- AuditLogへ承認者、理由テンプレート、期限、対象safe IDを保存する
- OpenAPI、Backend、Frontend、RSpec、Playwrightが同期されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- failed job discard承認request
- 承認/却下API
- discard実行時の承認gate
- Frontend承認状態表示

## 非スコープ

- retryの二人承認
- Slack実通知
- 外部ワークフロー承認ツール連携
- bulk discard

## 関連レビュー

- `docs/review/20260707_failed_job_notification_approval_slo_gate_design_review.md`
- `docs/review/20260707_failed_job_notification_approval_slo_gate_implementation_review.md`

## レビュー結果

P1。世界レベルSaaS基準では、本番discardは不可逆性が高く、方針表示だけでは不足する。DB/API強制が必要である。

## 次アクション

1. approval event table案と既存Review model活用案を比較する。
2. OpenAPIで承認request/approve/reject/execute flowを定義する。
3. Security/QAレビュー後にBackend、Frontend、E2Eへ進む。
