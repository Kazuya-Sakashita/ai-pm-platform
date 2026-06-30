# 2026-07-01 GitHub Connection State Nonceレビュー

## 評価日時

2026-07-01 07:17 JST

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

## 対象Issue

- ISSUE-004
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

## 対象成果物

- `backend/db/migrate/20260701073000_create_github_connection_states.rb`
- `backend/app/models/github_connection_state.rb`
- `backend/app/services/github_integration/connection_state.rb`
- `backend/app/controllers/api/v1/integration_accounts_controller.rb`
- `backend/spec/models/github_connection_state_spec.rb`
- `backend/spec/services/github_integration/connection_state_spec.rb`
- `backend/spec/requests/api/v1/integration_accounts_spec.rb`
- `docs/architecture/20260701_github_app_provider_implementation.md`

## G-STACK

### Goal

GitHub App connection callbackのstate replayを防止し、署名付きstateを一度だけ使えるようにする。

### Strategy

stateの生値は保存せず、payloadにnonceを含める。nonceとstateはSHA-256 digestだけをDBへ保存し、callback時にnonce digestをロック付きで消費する。

### Tactics

- `github_connection_states` を追加する。
- `nonce_digest` と `state_digest` をuniqueにする。
- `ConnectionState.generate` でnonceを生成し、署名付きpayloadとDBレコードを作る。
- `ConnectionState.consume!` で署名、期限、DB保存nonce、project/repository一致、未消費状態を確認する。
- 署名検証後のcallback処理で `consumed_at` を保存し、同じstateの再利用を拒否する。

### Assessment

model spec、service spec、request specで、生成、消費、replay拒否、期限切れ拒否、DBに存在しないnonce拒否を確認した。全RSpec、OpenAPI verify、frontend build、E2Eも成功。

### Conclusion

state replay防止としてMVP品質は満たした。ただしcallback失敗時にstateを消費するかの方針、期限切れstate cleanup、live GitHub App smokeはまだ残る。

### Knowledge

callbackの検証順序は、署名検証、nonce消費、GitHub API照合、integration account保存。現状はnonce消費後にGitHub API照合が失敗すると再試行できないため、運用方針をADRで決める必要がある。

## 良かった点

- stateの生値をDB保存せず、digestだけを保存した。
- nonce digestとstate digestにunique制約を付けた。
- `with_lock` で二重callbackの競合に備えた。
- request specで同じstateの2回目callbackがGitHub API照合前に拒否されることを確認した。
- 既存のGitHub installation verificationと自然に接続できた。

## 改善点

- callback失敗時にstateを消費済みにする現在仕様は安全寄りだが、ユーザー再試行性は低い。
- 期限切れstateのcleanup jobが未実装。
- live GitHub App credentialでのconnect + publish smokeが未実施。
- state digestは保存しているが、監査UIや検索APIでは未利用。
- 認証/認可が未実装のため、接続開始APIの悪用防止は未完了。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | 実GitHub App credentialでconnect + publish smokeを実施 | Issue #4クローズ判定に必須 |
| P0 | publish reconciliation ADRを作成する | 二重Issue防止に必須 |
| P1 | callback失敗時のstate消費方針をADR化する | UXと安全性のトレードオフ整理 |
| P1 | 期限切れstate cleanup jobを追加する | 運用保守に必要 |
| P1 | 認証/認可をconnect/disconnect APIへ接続 | 本番公開に必須 |
| P2 | state監査UI/APIを追加する | 運用可視性改善 |

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 署名state、GitHub API照合、nonce保存で低減 | live smokeで実payloadを確認 |
| Tampering | state改ざんとDB未登録nonceを拒否 | nonce digestとstate digestの監査ログ連携 |
| Repudiation | connect started/completedはAuditLogあり | consumed_atをAuditLogにも残す |
| Information Disclosure | raw stateは保存しない | state digestをAPIへ露出しない方針を維持 |
| Denial of Service | state生成のrate limitなし | connect endpointにrate limitを追加 |
| Elevation of Privilege | project権限未実装 | 認証/認可Issueと接続APIを連動 |

## 次アクション

1. 実GitHub App credentialでconnect + publish smokeを行う。
2. publish reconciliation ADRを作成する。
3. 期限切れ `github_connection_states` cleanup jobを追加する。
4. callback失敗時のstate消費方針をADR化する。
5. 認証/認可Issueとconnect/disconnect API公開制御を接続する。

## 検証結果

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/models/github_connection_state_spec.rb spec/services/github_integration/connection_state_spec.rb spec/requests/api/v1/integration_accounts_spec.rb spec/services/github_integration/installation_verifier_spec.rb`: 19 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec`: 97 examples, 0 failures
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
