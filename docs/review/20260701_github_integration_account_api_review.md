# 2026-07-01 GitHub Integration Account APIレビュー

## 評価日時

2026-07-01 16:42 JST

## 評価担当

Codex

- CTO
- Tech Lead
- Backend Architect
- Security Engineer
- QA
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- API First

## 対象Issue

- ISSUE-004
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

## 対象成果物

- `docs/api/openapi.yaml`
- `frontend/lib/api/schema.d.ts`
- `backend/app/controllers/api/v1/integration_accounts_controller.rb`
- `backend/app/services/github_integration/connection_state.rb`
- `backend/config/routes.rb`
- `backend/spec/requests/api/v1/integration_accounts_spec.rb`

## G-STACK

### Goal

GitHub App providerを実運用で使うために、ProjectとGitHub App installationを紐付けるAPIを追加する。

### Strategy

OpenAPIに既に存在したIntegrations設計をGitHub App方式へ修正し、Rails実装を追加する。callbackではRails署名付きstateを検証し、project/repository差し替えを防ぐ。

### Tactics

- `GET /projects/{project_id}/integrations` で接続一覧を返す。
- `POST /projects/{project_id}/integrations/github/connect` でinstallation URLと署名stateを返す。
- `POST /integrations/github/callback` でstateを検証し、`integration_accounts` をupsertする。
- `POST /projects/{project_id}/integrations/github/disconnect` で接続状態を `revoked` にする。
- connect/callback/disconnectをAuditLogへ記録する。

### Assessment

OpenAPI lint/typegen、request spec、全RSpec、frontend build/E2Eで回帰なし。state署名により、callbackリクエストでproject/repositoryを任意差し替えできない構造になった。

### Conclusion

GitHub App providerを使うためのMVP接続APIとしては前進。ただし実GitHub redirect payload、Webhook、認証/CSRF、live smokeは未検証であり、世界レベルSaaS基準ではまだproduction readyではない。

### Knowledge

connection stateは15分TTL。GitHub App install flowの正式payload確認後、必要ならcallback schemaを再調整する。

## 良かった点

- OpenAPIを先にGitHub App方式へ寄せ、実装と型生成を同期した。
- 署名付きstateにproject/repository/expiryを含め、callback本文のrepository差し替えを防いだ。
- connection開始、完了、disconnectをAuditLogへ残した。
- `integration_accounts` の実フィールドにOpenAPI schemaを合わせた。
- 既存のGitHub publish gate/providerに自然に接続できるAPIになった。

## 改善点

- GitHubからの実redirect payloadを使ったstaging/live検証が未実施。
- 現時点では認証/認可が未実装のため、connect/disconnect APIを本番公開するには危険が残る。
- GitHub App webhookによるinstallation revoked/permissions changed同期が未実装。
- callbackでGitHub APIへinstallation実在確認をしていない。
- state replay防止はTTLのみで、ワンタイム使用済みstate管理は未実装。
- disconnectはGitHub側のinstallation削除ではなく、ローカル状態のrevoked化に留まる。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | 実GitHub Appでconnect callbackとpublishのstaging smokeを行う | Issue #4クローズ判定に必須 |
| P0 | 認証/認可前提のconnect/disconnect公開制御を追加 | 本番公開に必須 |
| P0 | callback時にGitHub APIでinstallation/repository/permissionsを検証 | なりすまし・誤接続防止に必須 |
| P1 | webhook署名検証とinstallation状態同期 | 運用安全性に必要 |
| P1 | state replay防止のnonce保存 | SaaS品質向上 |
| P2 | disconnect UXとreconnect UXをFrontendへ追加 | UX改善 |

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 署名stateでproject/repositoryは保護。installation実在確認は未実装 | callback後にGitHub APIでinstallationを照合 |
| Tampering | state改ざんは検知可能 | nonce保存でreplayも検知 |
| Repudiation | AuditLogあり | 認証後にactor_idを実ユーザーへ接続 |
| Information Disclosure | token/private keyは扱わないAPI | callback errorにraw GitHub payloadを保存しない方針を維持 |
| Denial of Service | rate limitなし | connect/callbackにrate limitを追加 |
| Elevation of Privilege | 認可未実装 | Project membership/roleを導入 |

## 次アクション

1. 実GitHub Appでconnect callbackからpublishまでstaging smokeを行う。
2. callback時にGitHub APIでinstallation/repository/permissionsを検証する。
3. Webhook署名検証とinstallation状態同期を実装する。
4. 認証/認可Issueと接続API公開制御を連動させる。
5. live smoke後にIssue #4のクローズ判定を行う。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/models/integration_account_spec.rb`: 14 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `bundle exec rspec`: 84 examples, 0 failures
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
