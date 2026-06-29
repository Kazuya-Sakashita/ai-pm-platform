# 20260630_github_app_implementation_preparation_review

## 評価日時

2026-06-30 06:50 JST

## 評価担当

Codex as CTO, Backend Architect, Security Engineer, DevOps, QA

## 使用フレームワーク

STRIDE、OWASP Top 10、DORA Metrics、ISO25010

## 評価対象

`docs/architecture/20260630_github_app_implementation_preparation.md`

## 良かった点

- GitHub App作成手順、callback URL、webhook URL、環境変数が明文化された。
- MVP権限がMetadata read-onlyとIssues read/writeに限定され、過剰権限を避けている。
- installation access tokenのオンデマンド生成、期限前失効、ログ禁止が定義された。
- publish idempotencyのDB制約とretry/backoff方針が具体化された。
- webhook署名検証、delivery id冪等性、safe_metadata保存が設計に入った。
- テスト方針が正常系、重複、権限、署名、disconnect、監査まで含んでいる。

## 改善点

- GitHub API client libraryが未選定。
- local開発でwebhookを受ける手段が未定義。
- GitHub App manifestを使うか手動設定にするか未決。
- private key rotationの運用UIや手順がまだ薄い。
- OpenAPIへ `/webhooks/github` とtest/repository endpointを追加するか未決。

## 優先順位

1. P0: GitHub API client libraryを選定する
2. P0: OpenAPIへwebhook endpointを追加する
3. P0: DB設計へGitHub installation/publish idempotency項目を反映する
4. P1: local webhook開発手順を定義する
5. P1: private key rotation手順を作成する

## 次アクション

- ISSUE-013としてBackend実装準備を登録する。
- ISSUE-008のDB設計強化へGitHub項目を反映する。
- OpenAPIにwebhook endpointを追加する。

## Issue番号

ISSUE-012、ISSUE-013

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。

