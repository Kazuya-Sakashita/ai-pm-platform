# 2026-07-01 GitHub Callback Verificationレビュー

## 評価日時

2026-07-01 07:04 JST

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
- API First
- ISO25010

## 対象Issue

- ISSUE-004
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

## 対象成果物

- `backend/app/services/github_integration/installation_verifier.rb`
- `backend/app/services/github_issue_publish/http_client.rb`
- `backend/app/controllers/api/v1/integration_accounts_controller.rb`
- `backend/spec/services/github_integration/installation_verifier_spec.rb`
- `backend/spec/requests/api/v1/integration_accounts_spec.rb`
- `docs/api/openapi.yaml`
- `frontend/lib/api/schema.d.ts`
- `docs/architecture/20260701_github_app_provider_implementation.md`

## G-STACK

### Goal

GitHub App callback時に、リクエスト本文だけでなくGitHub APIでinstallation、permissions、repository accessを照合する。

### Strategy

callback本文の `granted_permissions` を信頼しない。署名付きstateでproject/repositoryを固定し、GitHub App JWTと一時installation tokenでGitHub APIから検証済み情報を取得して保存する。

### Tactics

- `GET /app/installations/{installation_id}` でinstallation実在、account、permissionsを確認する。
- Issues write権限がないinstallationは接続しない。
- installation access tokenを都度発行する。
- `GET /installation/repositories` で対象repositoryがinstallationに含まれることを確認する。
- GitHubから取得したpermissions/accountだけを `integration_accounts` へ保存する。
- OpenAPIのcallback requestから `granted_permissions` 必須を外す。

### Assessment

request specとservice specで、正常系、権限不足、repository不一致、state不正、GitHub verification失敗を検証した。全RSpec、OpenAPI verify、frontend build、E2Eも成功した。

### Conclusion

callbackのなりすまし耐性は改善した。MVPとしてはGitHub App接続の安全性が一段上がったが、state replay防止、live GitHub App smoke、webhook同期は未実装のためproduction readyではない。

### Knowledge

GitHub API照合はcallback時点で行い、publish時は保存済み `integration_accounts` とinstallation token発行で再確認する二段構えにする。

## 良かった点

- callback本文のpermissionsを信頼しない設計へ改善した。
- GitHub App JWT、installation token、repository listの3段階で実在性を確認できる。
- 対象repositoryがinstallationに含まれない場合は接続を作成しない。
- GitHub API失敗時もsafe errorのみをAPIに返す。
- OpenAPIと生成型を実装に同期した。
- 既存publish providerと同じHTTP clientを拡張し、テストで外部通信なしに検証できる。

## 改善点

- state replay防止のnonce保存が未実装。
- GitHub App live credentialを使ったconnect + publish smokeが未実施。
- webhook署名検証とinstallation revoked/permissions changed同期が未実装。
- GitHub API rate limitやRetry-After専用のハンドリングがない。
- callback成功後にユーザーを戻すredirect UXは未実装。
- 認証/認可が未実装のため、本番公開時はconnect/disconnect APIにproject権限制御が必要。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | GitHub App live credentialでconnect + publish smokeを実施 | Issue #4クローズ判定に必須 |
| P0 | state nonce保存でreplayを防止 | callback securityに必須 |
| P0 | 認証/認可をconnect/disconnectへ接続 | 本番公開に必須 |
| P1 | webhook署名検証とinstallation状態同期 | 運用安全性に必要 |
| P1 | rate limit/retry/backoff | 信頼性向上 |
| P2 | reconnect/redirect UX | 利用体験改善 |

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | GitHub API照合でinstallation spoofingを低減 | app idとinstallation ownerの追加照合をlive smoke後に強化 |
| Tampering | 署名stateでproject/repository改ざんを検知 | state nonceをDB保存し、再利用を拒否 |
| Repudiation | AuditLogにconnect started/completedを保存 | 認証後にactor_idを実ユーザーへ接続 |
| Information Disclosure | tokenは保存しない。safe errorのみ返す | GitHub error messageのallowlist化 |
| Denial of Service | rate limit対応なし | callback endpointにrate limitとretry policyを追加 |
| Elevation of Privilege | Issues write権限を必須確認 | Project role permissionを追加 |

## 次アクション

1. state nonce保存を追加し、callback replayを拒否する。
2. 実GitHub App credentialでconnect + publish smokeを行う。
3. webhook署名検証とinstallation status同期を実装する。
4. publish reconciliation ADRを作成する。
5. 認証/認可Issueとconnect/disconnect API公開制御を接続する。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_integration/installation_verifier_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/models/integration_account_spec.rb`: 20 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `bundle exec rspec`: 90 examples, 0 failures
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
