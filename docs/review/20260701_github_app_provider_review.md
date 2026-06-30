# 2026-07-01 GitHub App Provider実装レビュー

## 評価日時

2026-07-01 16:05 JST

## 評価担当

Codex

- CTO
- Tech Lead
- AI Architect
- Backend Architect
- DevOps
- Security Engineer
- QA
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DDD
- ADR

## 対象Issue

- ISSUE-004
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

## 対象成果物

- `backend/app/models/integration_account.rb`
- `backend/db/migrate/20260701065000_create_integration_accounts.rb`
- `backend/app/services/github_issue_publish/github_app_provider.rb`
- `backend/app/services/github_issue_publish/http_client.rb`
- `backend/spec/models/integration_account_spec.rb`
- `backend/spec/services/github_issue_publish/github_app_provider_spec.rb`
- `docs/architecture/20260701_github_app_provider_implementation.md`

## G-STACK

### Goal

承認済みIssue Draftを、GitHub App installation tokenを使ってGitHub Issueとして公開できる実装土台を作る。

### Strategy

安全停止をデフォルトとし、`GITHUB_ISSUE_PUBLISH_PROVIDER=github_app` が設定された場合のみ実GitHub providerを使う。installation access tokenは保存せず、Project単位の `integration_accounts` に接続状態と最小メタデータだけを保存する。

### Tactics

- GitHub App JWTをRS256で生成する。
- installation access tokenを公開時に都度発行する。
- Issues write権限がない場合はpublish前に停止する。
- GitHub APIのraw responseやtokenをDB/APIへ出さず、safe errorのみ保存する。
- Idempotency-Keyの生値はGitHub Issue本文へ出さず、短縮digestだけを監査markerに残す。

### Assessment

fake HTTP clientによる単体テストで、installation token発行、Issue作成、権限不足、未接続、GitHub API失敗を確認できた。既存publish gate、RSpec全体、Frontend build/E2Eへの回帰も確認済み。

### Conclusion

MVPの実GitHub publish providerとして前進。ただしlive GitHub App credentialによる実API検証、installation callback/API、reconciliationが未実装のため、Issue #4はまだクローズ不可。

### Knowledge

GitHub App providerはOpenAPI/Issueレビューゲートの後段に接続する。今後はGitHub App installation flowとwebhook同期を追加し、`integration_accounts` を手動作成に依存しない状態へ進める。

## 良かった点

- GitHub App方式をADR-0003の方針どおり実装し、OAuth/PATへ寄せなかった。
- installation access tokenを永続保存しない設計にした。
- ProjectとRepositoryの接続状態を `integration_accounts` として明示し、将来のGitHub/Slack/Notion連携にも広げやすい形にした。
- `ProviderFactory` はデフォルトdisabledを維持し、本番設定ミスで勝手に外部送信しない。
- GitHub API呼び出しをHTTP clientへ分離し、RSpecで外部通信なしに検証できる。
- 権限不足、未接続、token発行失敗、Issue作成失敗をsafe errorで返す。
- Idempotency-Keyの生値をGitHub Issue本文へ残さないようにした。

## 改善点

- GitHub App installation callback/APIが未実装で、`integration_accounts` 作成はまだ手動または将来実装に依存する。
- 実GitHub App credentialを使ったlive publish検証が未実施。
- GitHub Issue作成成功後、DB保存前に障害が起きた場合のreconciliationが未実装。
- `integration_accounts` のrepository unique indexは大文字小文字差分を完全には吸収していない。
- GitHub API rate limit、secondary rate limit、Retry-Afterを専用に扱っていない。
- webhook署名検証、installation revoked、permissions changedの同期が未実装。
- Issue body生成は最低限で、AI PMとしてのIssue品質評価やテンプレートバージョン管理は未接続。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | installation callback/APIで `integration_accounts` を自動作成する | 実運用に必須 |
| P0 | staging/live GitHub App credentialでpublish smokeを行う | Issue #4クローズ判定に必須 |
| P0 | 外部API成功後DB保存失敗時のreconciliation設計 | 二重Issue作成防止に必須 |
| P1 | webhook署名検証とinstallation status同期 | 運用安全性に必要 |
| P1 | rate limit/retry/backoffをproviderに追加 | SaaS品質に必要 |
| P2 | repository名のcase-insensitive unique制約 | データ品質改善 |

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | installation rowが手動作成依存のため、callback state検証は未実装 | GitHub App installation callbackでstate検証を追加 |
| Tampering | publish gateはあるが、承認後のIssue Draft改ざん検知は未実装 | approved content hashを保存し、publish前に照合 |
| Repudiation | Job/AuditLogにpublish結果を残せる | actor_idをユーザー認証実装後に実ユーザーへ接続 |
| Information Disclosure | token/private keyは保存しない。Idempotency-Key生値も外部本文に出さない | safe errorの許容語彙をテーブル化 |
| Denial of Service | rate limit専用処理は未実装 | Retry-After、backoff、job retry policyを追加 |
| Elevation of Privilege | Issues writeのみ確認する | installation permissionsの定期同期と差分監査を追加 |

## ISO25010評価

- 機能適合性: B。GitHub App providerの基本経路は実装済みだがlive検証待ち。
- 信頼性: B-。safe failureはあるがreconciliation未実装。
- セキュリティ: B。token非保存と最小権限は良いがcallback/webhook未実装。
- 保守性: B+。provider/client/model分離は良い。
- 試験性: A-。fake clientで外部通信なしに主要分岐を検証できる。
- 運用性: C+。環境変数と手動integration rowが必要。

## 次アクション

1. GitHub App installation callback/APIを設計・実装し、`integration_accounts` を自動作成する。
2. GitHub App credentialを使うstaging smoke手順を `docs/release/` に追加する。
3. publish reconciliation ADRを作成し、GitHub Issue重複防止策を決める。
4. webhook署名検証とinstallation revoked/permissions changed同期をIssue化する。
5. live publish検証後にIssue #4をクローズ判定する。

## 検証結果

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/models/integration_account_spec.rb spec/services/github_issue_publish/github_app_provider_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 20 examples, 0 failures
- `bundle exec rspec`: 78 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
