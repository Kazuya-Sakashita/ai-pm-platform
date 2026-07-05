# Auth session/revocation/keyring implementation review

## 評価日時

2026-07-06 06:54:23 JST

## 評価担当

Codex Review Orchestrator / Security Engineer / Backend Architect / QA / DevOps

Subagents:

- Security/QA Agent: Jason
- Backend/Auth Architect Agent: Planck

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## Issue番号

ISSUE-045

## 評価対象

- `backend/db/migrate/20260706000100_create_authentication_foundation.rb`
- `backend/app/models/auth_actor.rb`
- `backend/app/models/auth_session.rb`
- `backend/app/models/auth_token_revocation.rb`
- `backend/app/models/security_event.rb`
- `backend/app/services/authentication/keyring.rb`
- `backend/app/services/authentication/session_authenticator.rb`
- `backend/app/services/authentication/jwt_verifier.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/spec/services/authentication/jwt_verifier_spec.rb`
- `backend/spec/requests/api/v1/authentication_session_spec.rb`
- `backend/spec/models/authentication_foundation_spec.rb`

## 良かった点

- `auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` を追加し、ADR-0017のserver-side auth stateを実装した。
- `Authentication::Keyring` が `active`、`verify_only`、`retired`、`disabled` keyを扱い、unknown/retired/disabledをsafe codeで拒否できる。
- `Authentication::SessionAuthenticator` が `sid/sv/jti`、session status、actor status、session version、revoked `jti` を検証する。
- `current_actor_id` はAuthorization headerがある場合にlegacy `X-Actor-Id` fallbackへ落ちない。Security/QA AgentのP0指摘に対応した。
- `AuthTokenRevocation` はraw `jti` ではなくSHA-256 digestだけを保存する。
- `security_events` はglobal auth lifecycle用に分離し、project `AuditLog` と責務を混同していない。
- 既存controllerの `current_actor_id` contractを維持し、blast radiusを抑えた。

## 改善点

- `AUTH_JWT_REQUIRE_SESSION_CLAIMS` は現時点でdefault falseであり、production必須化は後続の発行側/Frontend整備後に行う必要がある。
- token issuer、refresh token、session list/revoke APIはISSUE-046以降で未実装である。
- keyring JSONは `secret_env` を使えるが、deployment secret store validationやduplicate active key policyはrunbook/CI gate側でさらに固める必要がある。
- `security_events` のretention、検索UI、alert連携は未実装である。
- max TTL defaultを900秒にしたため、外部で発行している長寿命access tokenは再発行が必要になる可能性がある。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | session claim必須化とtoken発行導線 | ISSUE-046 |
| P1 | key rotation smoke / release gate | ISSUE-047 |
| P1 | older workflow endpoint auth coverage | ISSUE-048 |
| P2 | security event retention/monitoring | ISSUE-047または後続 |
| P2 | external IdP/JWKS互換 | 後続ADR/Issue |

## 次アクション

1. PRを作成し、CI成功後にマージする。
2. ISSUE-045をGitHub上でクローズする。
3. 次はISSUE-046またはISSUE-048へ進む。認証基盤の流れを優先するならISSUE-046、既存endpointのリスク低減を優先するならISSUE-048。

## 検証結果

- `bundle exec rspec spec/services/authentication/jwt_verifier_spec.rb spec/requests/api/v1/authentication_session_spec.rb spec/models/authentication_foundation_spec.rb`: 22 examples, 0 failures
- `bundle exec rspec spec/requests/api/v1/projects_spec.rb spec/requests/api/v1/project_memberships_spec.rb spec/requests/api/v1/conversation_imports_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb spec/services/authentication/jwt_verifier_spec.rb spec/requests/api/v1/authentication_session_spec.rb spec/models/authentication_foundation_spec.rb`: 74 examples, 0 failures
- `bundle exec rspec`: 239 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 26 passed

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | JWTをsession/revocation/keyringで失効可能にするbackend foundationを作る |
| Strategy | 既存API contractを維持しつつ、new claim tokenではDB-backed validationへ入る |
| Tactics | migration/model、Keyring、SessionAuthenticator、safe security event、request/service specs |
| Assessment | ISSUE-045のbackend foundationとしては合格。production必須化は後続Issueが必要 |
| Conclusion | PR化してよい |
| Knowledge | 無効Bearerをlegacy fallbackさせないことが、移行期の最重要安全条件である |

## STRIDE

| Threat | 実装対応 |
| --- | --- |
| Spoofing | `sid/sv/jti` とsession stateを検証 |
| Tampering | unknown/retired/disabled keyを拒否 |
| Repudiation | `security_events` へ拒否eventをsafe metadataで保存 |
| Information Disclosure | raw token/raw `jti`/secretを保存しないspecを追加 |
| Denial of Service | auth state不整合時はsafe 401でfail closed |
| Elevation of Privilege | invalid Bearer + `X-Actor-Id` fallbackを禁止 |

## AIレビュー比較

Security/QA Agent Jasonは、invalid/revoked/session-stale/key-invalid Bearer tokenがlegacy `X-Actor-Id` fallbackへ落ちるリスクをP0として指摘した。実装ではAuthorization headerが存在する場合に `current_auth_context` だけを使い、失敗時はlegacy fallbackしないよう修正した。

Backend/Auth Architect Agent Planckは、controllersの `current_actor_id` contractを維持し、rich auth contextを背後に追加するmigration planを推奨した。実装では `JwtVerifier::Result` に `auth_session`、`jti_digest`、`kid` を追加し、既存controller contractを維持した。

相違点:

- Security/QAはfail-closedとsafe metadataを最重視した。
- Backend/Authはblast radiusと移行互換を最重視した。

統合判断:

- 両方を採用し、legacy token互換は残すが、Bearer失敗時のlegacy fallbackは禁止した。
- `AUTH_JWT_REQUIRE_SESSION_CLAIMS` でsession claim必須化できるようにし、default必須化はISSUE-046以降に残した。

## 判定

合格。

ISSUE-045のbackend foundationは完了可能。ただし、production-grade完成にはISSUE-046、ISSUE-047、ISSUE-048の継続が必要である。
