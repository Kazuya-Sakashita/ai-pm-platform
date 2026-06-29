# ISSUE-012: GitHub App実装準備を行う

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/12

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

ISSUE-010でMVPのGitHub連携方式はGitHub App採用と決定した。Backend実装前に、GitHub App作成手順、環境変数、installation token生成、callback/webhook、publish idempotencyを具体化する必要がある。

## 目的

GitHub App連携を実装できる状態まで、設定、環境変数、DB制約、API詳細、運用手順を準備する。

## 完了条件

- GitHub App作成手順がある
- callback URLとwebhook URLが定義されている
- 必要な環境変数一覧がある
- GitHub App private key保存方針がある
- installation access token生成/キャッシュ方針がある
- GitHub publish idempotencyのDB制約がある
- rate limit/retry/backoff方針がある
- 実装準備レビューが `docs/review/` に保存されている

## スコープ

- GitHub App設定手順
- Backend実装前設計
- 環境変数
- DB制約
- retry/backoff

## 非スコープ

- GitHub Appの実作成
- Backend実装
- UI実装

## 関連レビュー

- `docs/review/20260630_github_integration_security_review.md`
- `docs/review/20260630_github_app_implementation_preparation_review.md`

## レビュー結果

GitHub App採用判断は妥当。ただし、実装前にはApp作成手順、installation token、idempotency、retry/backoffの具体化が必要。

## 次アクション

- GitHub App実装準備資料は `docs/architecture/20260630_github_app_implementation_preparation.md` に作成済み
- publish idempotency制約は同資料に定義済み
- 環境変数とprivate key方針は同資料に定義済み
- ISSUE-013としてBackend/Frontend実装準備へ進める

## 進捗

完了。GitHub Issue同期済み。
