# ISSUE-060: failed job retry/discardのstaging/production worker smoke証跡を整備する

## Issue番号

ISSUE-060

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/89

## 背景

ISSUE-056でfailed job再実行/破棄のMVP操作は実装済みである。一方、実worker環境でretry/discardが期待通りに動作する証跡はまだない。

ISSUE-004の残課題にはstaging/production worker smokeがあり、failed job操作もrelease gateで確認すべき対象に含める必要がある。

## 目的

staging/production worker smoke runbookと証跡テンプレートにfailed job retry/discard確認を追加し、release判断で運用操作の実環境挙動を確認できるようにする。

## 完了条件

- staging worker smoke runbookにfailed job retry/discard確認手順が追加されている
- production smokeまたはrelease checklistに、本番で実行してよい条件と禁止条件が明記されている
- 証跡テンプレートに操作対象、理由テンプレート、operator、AuditLog、Queue health再取得結果が含まれる
- secret、raw exception、backtrace、job argumentsを証跡へ保存しないルールが明記されている
- GitHub Issue #4のrelease gateと接続されている
- レビュー結果が `docs/review/` に保存されている

## スコープ

- failed job retry/discard smoke手順
- staging/production worker smoke runbook更新
- release checklistまたは証跡テンプレート更新
- Security / DevOps / QAレビュー

## 非スコープ

- failed job操作APIの追加実装
- Project境界の厳密化
- GitHub App live smokeそのもの
- 実staging/production環境への接続実行

## 関連レビュー

- `docs/review/20260704_queue_health_monitoring_implementation_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_implementation_review.md`
- `docs/review/20260707_failed_job_followup_issue_split_review.md`

## レビュー結果

P1。実装済みの運用操作を本番運用可能と判断するには、実worker下でのsmoke証跡が必要である。ただし環境credentialが必要なため、実行そのものはrelease gateとして扱い、まずrunbookと証跡テンプレートを整備する。

## 次アクション

1. 既存のstaging worker smoke runbookとrelease checklistを確認する。
2. failed job retry/discardの安全な確認手順を追記する。
3. 証跡テンプレートと禁止事項を追加する。
4. GitHub Issue #4へ接続し、release gate上の確認項目として同期する。
