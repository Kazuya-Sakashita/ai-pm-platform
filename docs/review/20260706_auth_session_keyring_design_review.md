# Auth session/revocation/keyring design review

## 評価日時

2026-07-06 06:49:15 JST

## 評価担当

Codex Review Orchestrator / Security Engineer / Backend Architect / QA / DevOps

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- ADR

## Issue番号

ISSUE-045

## 評価対象

- `docs/issue/ISSUE-045_auth_session_revocation_keyring_backend_foundation.md`
- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`
- `docs/security/20260706_jwt_revocation_session_key_rotation_design.md`
- `backend/app/services/authentication/jwt_verifier.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/spec/services/authentication/jwt_verifier_spec.rb`
- `backend/spec/support/authentication_spec_helpers.rb`
- `backend/db/schema.rb`

## 良かった点

- ISSUE-042で `kid/sid/sv/jti`、server-side session、`jti` denylist、keyring、security eventの採用判断が完了している。
- 現行JWT verifierはsafe errorを返す形になっており、拡張時にAPI responseへraw tokenやclaimを出さずに済む。
- `project_memberships.actor_id` が既存authorization subjectとして機能しており、`auth_actors.subject` との接続点が明確である。
- OpenAPIには認証失効系のsafe error codeがすでに定義されている。

## 改善点

- token issuer/login UIがまだないため、`kid/sid/sv/jti` を即時必須化すると既存API利用とテストが破綻する。
- keyring設定の形式、legacy secretとの互換境界、retired/disabled keyのsafe error codeを明確に実装する必要がある。
- `security_events` はglobal auditであり、project `AuditLog` とは責務を混同してはならない。
- raw `jti`、raw token、IP、User-Agent全文を保存しないguardが必要である。
- auth store障害時はfail closedに寄せる必要があるが、現時点では可用性monitoringは後続Issueで扱う。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | DB-backed auth stateを追加 | `auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` |
| P1 | keyringとlegacy secret互換を実装 | `Authentication::Keyring` |
| P1 | `sid/sv/jti` session検証を実装 | `Authentication::SessionAuthenticator` |
| P1 | revoked/stale/retired keyをsafe 401で返す | `JwtVerifier::Error` |
| P1 | raw token/raw `jti`保存禁止をテストする | model/service specs |
| P2 | production必須化flagを追加 | `AUTH_JWT_REQUIRE_SESSION_CLAIMS` |

## 次アクション

1. migrationとmodelsを追加する。
2. keyringを追加し、`AUTH_JWT_KEYRING_JSON` とlegacy `AUTH_JWT_SECRET` を扱う。
3. session authenticatorを追加し、`sid/sv/jti` 付きtokenをDB stateで検証する。
4. service/request specsでrevoked session、stale version、revoked jti、unknown/retired key、legacy互換境界を固定する。
5. 実装レビューを `docs/review/` に保存する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | JWTを失効可能でrotation可能なproduction-grade foundationへ進める |
| Strategy | 既存JWT互換を保ちつつ、new claim tokenではDB-backed validationを有効化する |
| Tactics | keyring、session authenticator、token revocation digest、security eventを追加する |
| Assessment | 段階導入であれば既存APIのblast radiusを抑えながらP1リスクを下げられる |
| Conclusion | 実装へ進めてよい。ただし必須化とsession UIは後続Issueで扱う |
| Knowledge | 認証基盤は一気に置き換えるより、発行側と検証側の互換期間を設計した方が安全である |

## STRIDE

| Threat | 対応 |
| --- | --- |
| Spoofing | session state、revoked jti、keyring statusで漏えいtokenを拒否 |
| Tampering | keyring statusとunknown/retired key拒否 |
| Repudiation | `security_events` に失効/拒否イベントを保存 |
| Information Disclosure | raw token/raw `jti`/secretを保存しない |
| Denial of Service | auth state不整合時はsafe 401でfail closed |
| Elevation of Privilege | actor/session version mismatchを拒否 |

## AIレビュー比較

Codex一次レビュー。Security/QA AgentとBackend/Auth Architect Agentのサブエージェントレビューは実行中であり、実装レビューへ統合する。

外部AIレビューは未実施。外部レビュー結果が追加された場合は、keyring形式、session version比較、security eventの保存粒度を比較する。

## 判定

条件付き合格。

ISSUE-045は実装へ進めてよい。ただし、既存token互換を残すfeature flag、safe error、raw secret非保存、request/service specを完了条件として扱う。
