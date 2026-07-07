# ISSUE-067: GitHub Webhook署名検証とinstallation状態同期を実装する

## Issue番号

ISSUE-067

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/106

登録日: 2026-07-07
状態: OPEN

## 背景

ISSUE-004では、承認済みRequirementからGitHub IssueとOpenAPIドラフトを生成し、GitHub Appで公開するMVP経路を整備した。一方で、GitHub App webhookの署名検証、delivery id冪等性、installation revoked / permissions changed同期は未実装であり、連携後の権限失効やrepository access変更をプロダクト側へ反映できない。

## 目的

GitHub App webhookを安全に受信し、署名検証済みのinstallation系イベントだけを処理して、`IntegrationAccount` の状態と権限情報を監査可能に同期する。

## 完了条件

- `POST /api/v1/webhooks/github` を実装する
- `X-Hub-Signature-256` を `GITHUB_WEBHOOK_SECRET` で検証する
- 署名不正、secret未設定、payload不正ではraw payloadを保存せず安全に失敗する
- `X-GitHub-Delivery` による冪等性を担保し、同じdeliveryの重複処理を避ける
- `installation.deleted` で該当 `IntegrationAccount` を `revoked` に更新できる
- `installation_repositories.removed` または権限不足イベントで対象repositoryの連携を `revoked` または `error` に更新できる
- `installation.created` / `installation_repositories.added` / 権限変更では安全なmetadataだけを保存し、必要に応じて `connected` / `error` を更新できる
- AuditLogへevent、delivery digest、installation id、repository、同期結果、safe errorを保存する
- OpenAPI、RSpec、設計レビュー、実装レビューを更新する

## スコープ

- Rails API route / controller
- GitHub webhook署名検証Service
- GitHub installation webhook同期Service
- webhook delivery冪等性の保存
- AuditLog safe metadata
- Request / Service RSpec
- OpenAPI同期

## 非スコープ

- GitHub webhook live delivery smoke
- GitHub App credential再設定手順
- GitHub Issue publish本体の再設計
- Slack通知
- PR自動作成、自動マージ

## 関連Issue

- ISSUE-004 / GitHub Issue #4
- ISSUE-012

## 関連レビュー

- `docs/review/20260630_github_integration_security_review.md`
- `docs/review/20260630_github_app_implementation_preparation_review.md`
- `docs/review/20260701_github_app_provider_review.md`
- `docs/review/20260701_github_callback_verification_review.md`
- `docs/review/20260704_github_app_live_smoke_runbook_review.md`
- `docs/review/20260707_github_webhook_signature_installation_sync_design_review.md`
- `docs/review/20260707_github_webhook_signature_installation_sync_implementation_review.md`

## レビュー結果

GitHub webhookは外部入力かつ権限状態を変更するため、署名検証と冪等性がP0である。署名検証前にpayloadを保存してはならず、delivery idも生値ではなくdigestで保存する。installation失効時に連携状態が残ると、ユーザーは公開可能に見えるが実際にはGitHub側で拒否されるため、UXと運用の両方で問題になる。

2026-07-07更新: `POST /api/v1/webhooks/github`、署名検証、delivery digest冪等性、`GithubWebhookDelivery`、installation deleted / repository removed / permission downgrade同期、safe AuditLog、OpenAPI responseの `delivery_digest` 化、RSpecを追加した。raw payload、signature、secret、delivery id生値は保存・返却しない。実GitHub webhook live delivery smokeは未実施のため、ISSUE-004のlive gateとして継続する。

## 優先度

P1

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後にGitHub Issue #106をクローズする。
3. 実GitHub App webhook delivery smokeはISSUE-004のrelease gateとして継続する。
