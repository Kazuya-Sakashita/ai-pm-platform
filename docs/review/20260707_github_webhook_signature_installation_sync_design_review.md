# 2026-07-07 GitHub Webhook署名検証とinstallation状態同期 設計レビュー

## 評価日時

2026-07-07 20:33:51 JST

## 評価担当

Codex as Security Engineer / Backend Architect / Tech Lead / QA

外部AIレビュー: 未実施。Claude / ChatGPT等の外部AIレビューは追加待ち。

## Issue番号

ISSUE-067 / GitHub Issue #106

## 対象成果物

- `docs/issue/ISSUE-067_github_webhook_signature_and_installation_sync.md`
- `docs/api/openapi.yaml`
- `backend/config/routes.rb`
- `backend/app/controllers/api/v1`
- `backend/app/services/github_integration`
- `backend/app/models/integration_account.rb`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DDD

## 評価サマリー

ISSUE-004のMVP経路は、GitHub App接続、Issue公開、reconciliation、callback failure AuditLog、Frontend再接続導線まで到達している。一方でGitHub webhook未実装のため、GitHub側でinstallationが削除されたりrepository accessやpermissionsが変わった場合に、`IntegrationAccount` が古い接続状態を保持する。

世界レベルSaaS基準では、外部連携の権限状態は接続時だけでなく継続同期が必要である。特にGitHub App webhookは外部から到達する公開endpointであり、署名検証前のpayload保存、delivery id生値保存、冪等性なしの重複処理、raw repository payload保存を禁止する必要がある。

## G-STACK評価

### Goal

GitHub Appの権限状態を安全に同期し、失効済み連携や権限不足連携でGitHub Issue公開を続行しない。

### Strategy

署名検証、delivery冪等性、event routing、IntegrationAccount更新、AuditLog記録を分離する。Controllerは受信とレスポンス、Serviceは検証と同期、Modelは短い状態更新に限定する。

### Tactics

- `POST /api/v1/webhooks/github` を追加する。
- `GithubIntegration::WebhookSignatureVerifier` でHMAC SHA-256を定数時間比較する。
- `GithubWebhookDelivery` でdelivery digest、event、status、processed_atを保存する。
- `GithubIntegration::WebhookProcessor` でinstallation系イベントだけを許可する。
- `installation.deleted` は該当installationの `IntegrationAccount` を `revoked` へ更新する。
- `installation_repositories.removed` は対象repositoryの `IntegrationAccount` を `revoked` へ更新する。
- permissions不足は `error` と `last_error_safe` へ同期する。
- AuditLog metadataはallowlist化し、delivery idはdigestのみ保存する。

### Assessment

OpenAPIには `/webhooks/github` が既に存在するが、Rails route/controller/serviceが未実装である。`IntegrationAccount` は `connected / error / revoked` を持つため状態同期先として使える。delivery冪等性の永続化は未整備のため、migration追加が必要である。

### Conclusion

実装へ進んでよい。ただしP0として、署名検証前payload保存禁止、delivery冪等性、raw payload非保存、権限失効時のpublish停止、RSpecでの安全失敗確認を満たすこと。

### Knowledge

外部連携の安全性は「接続できたか」だけではなく「接続状態が変わったときに正しく止まるか」で決まる。Webhook同期は派手ではないが、AI PMの自動公開機能を安全に運用するための土台である。

## STRIDE評価

| 脅威 | リスク | 対策 |
| --- | --- | --- |
| Spoofing | GitHub以外からinstallation削除を偽装される | `X-Hub-Signature-256` を必須検証 |
| Tampering | payload改ざんでrepositoryやinstallation idを書き換えられる | HMAC検証後のみ処理 |
| Repudiation | 同じdeliveryの再送や処理有無が追えない | delivery digest、event、status、AuditLogを保存 |
| Information Disclosure | raw payload、delivery id、secret、repository一覧をログへ保存する | metadata allowlist、digest保存、raw payload非保存 |
| Denial of Service | 重複deliveryで状態更新やAuditLogが増える | delivery冪等性とprocessed status |
| Elevation of Privilege | 権限削除後もconnected扱いで公開を続ける | revoked/error同期とpublish gateの既存connected判定を活用 |

## 良かった点

- OpenAPIにwebhook endpointの設計入口が既にある。
- `IntegrationAccount` が `revoked` と `error` を持ち、同期先の状態がある。
- GitHub callback失敗AuditLogやconnection state nonceで、safe metadata保存の既存パターンがある。
- GitHub Issue publish providerはconnected accountを参照するため、状態同期がpublish停止に直結しやすい。

## 改善点

- Rails route/controllerが未実装で、OpenAPIと実装が乖離している。
- delivery id冪等性を保存するtableがない。
- webhook secret未設定時の運用判断が未定義である。
- installation eventのrepository単位同期ルールが文書化されていない。
- live GitHub webhook delivery smokeは本Issueの非スコープだが、後続で証跡が必要である。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | 署名検証とsecret未設定時の安全失敗 | なりすまし防止 |
| P0 | delivery冪等性 | GitHub再送時の重複状態変更防止 |
| P0 | raw payload非保存 | webhookに含まれる外部情報の漏えい防止 |
| P0 | revoked/error同期 | 権限失効後の公開続行防止 |
| P1 | OpenAPIとRSpec同期 | API駆動開発の維持 |
| P1 | live webhook smoke runbook更新 | 実credential検証へ接続 |

## 次アクション

1. `github_webhook_deliveries` migration/modelを追加する。
2. Webhook署名検証Serviceとprocessorを追加する。
3. Request specとService specで署名不正、secret未設定、重複delivery、installation deleted、repository removedを固定する。
4. 実装レビューを `docs/review/20260707_github_webhook_signature_installation_sync_implementation_review.md` として保存する。

## 判定

条件付き合格。

署名検証、冪等性、safe metadata、状態同期のP0条件を満たす前提で実装へ進んでよい。
