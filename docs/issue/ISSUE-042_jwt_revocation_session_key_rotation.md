# ISSUE-042: JWT revocation/session version/key rotationを設計する

## Issue番号

ISSUE-042

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42

登録日: 2026-07-05
クローズ日: 2026-07-05 21:43:47 UTC / 2026-07-06 06:43:47 JST
クローズPR: https://github.com/Kazuya-Sakashita/ai-pm-platform/pull/49
マージコミット: `a3e240992b5fcc83f1ae45ddeb6b802c697fd26f`
最終状態: CLOSED

## 背景

ISSUE-039でAPI actor identityをBearer JWTの `sub` から導出し、production pathで任意の `X-Actor-Id` を信頼しない方針へ移行した。これにより、DM系APIとProjects API最小範囲のspoofing、権限昇格、AuditLog actor否認リスクは下がった。

一方で、ISSUE-039のADRでは短命Bearer tokenを前提にserver-side revocation list、session version、`jti`、key rotationを非スコープとしてリスク受容している。世界レベルSaaS基準では、漏えいtokenの即時失効、logout everywhere、device単位失効、secret/key rotation、監査可能な失効履歴が必要になる。

## 目的

JWT actor identity基盤をproduction運用へ近づけるため、token失効、session version、`jti` replay防止、key rotation、監査ログ、OpenAPI/Frontendへの影響を設計する。

## 完了条件

- revocation/session version/key rotation方式のADRが `docs/decisions/` に保存されている
- JWT claim設計に `jti` またはsession version相当の扱いが定義されている
- token失効時のsafe error code/messageがOpenAPIに反映されている
- secret/key rotationの運用手順、旧key許容期間、rollback方針が定義されている
- logout everywhere、device単位失効、管理者強制失効の優先順位が整理されている
- 監査ログに失効、rotation、拒否イベントを残す方針が定義されている
- Security/QAレビューが `docs/review/` に保存されている
- 実装が必要な場合は、別Issueまたは本Issue内の実装タスクへ分解されている

## スコープ

- JWT revocation設計
- session versionまたは`jti`設計
- key/secret rotation設計
- safe error contract設計
- AuditLog/operation log方針
- OpenAPI影響整理
- Frontend再ログイン/失効導線の影響整理
- Security/QAレビュー

## 非スコープ

- SSO/SAML本番接続
- SCIM
- Organization横断RBAC
- full user management UI
- external IdP/JWKSの実装
- billing plan別権限

## 関連レビュー

- `docs/review/20260705_auth_jwt_actor_identity_design_review.md`
- `docs/review/20260705_auth_jwt_actor_identity_implementation_review.md`
- `docs/review/20260705_jwt_revocation_followup_issue_split_review.md`
- `docs/review/20260706_jwt_revocation_session_key_rotation_design_review.md`

## 関連ADR

- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`
- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

ISSUE-039の実装レビューでは、P0の `X-Actor-Id` spoofing排除とAuditLog actor mappingは完了した。一方で、revocation/session version/key rotationは短命Bearer tokenとしてリスク受容しており、production trustをさらに上げるには後続設計が必要と判定した。

2026-07-06にSecurity/DevOps AgentとBackend/Auth Architect Agentを使って専門家サブエージェントレビューを実施した。Security/DevOps Agentは漏えいtoken、単一HS256 secret、revocation audit不足、Frontend再ログイン導線不足をP1として指摘した。Backend/Auth Architect Agentは、現行実装がRails API-only、JWT first、非production `X-Actor-Id` fallback、ProjectMembership `actor_id` subjectであることを整理し、`auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` の段階導入を提案した。

統合判断として、ADR-0017で `kid/sid/sv/jti`、server-side session、`jti` denylist、keyring、security eventを採用した。OpenAPIには `AuthErrorCode` とUnauthorized examplesを追加し、Frontend日本語表示にも失効/rotation系safe messageを追加した。

## 設計結果

- JWT headerに `kid` を追加する方針を採用した。
- JWT claimsに `sid`、`sv`、`jti` を追加する方針を採用した。
- `auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` を後続実装のDB foundationとした。
- project-scoped `AuditLog` とglobal `security_events` の責務を分離した。
- 通常rotation、rollback、emergency key compromiseのrunbookを作成した。
- 失効、session stale、unknown/retired keyのsafe error contractをOpenAPIへ追加した。
- 実装範囲をISSUE-045からISSUE-048へ分割した。

## 後続Issue

- ISSUE-045: Auth session/revocation/keyring backend foundationを実装する
- ISSUE-046: Auth session APIsとFrontend再ログイン導線を実装する
- ISSUE-047: JWT key rotation staging smokeとproduction runbook gateを整備する
- ISSUE-048: Workflow endpointsのauth coverage gapを解消する

## 優先度

P1

理由:

- 漏えいtokenの即時失効ができない状態はenterprise trustの制約になる
- AI操作、DM整理、承認、削除の監査証跡と強く関係する
- 本格IdP/JWKSやSSOへ進む前に、内部session/tokenモデルの失効境界を決める必要がある
- ISSUE-040のmembership管理API/UIと並行して設計可能だが、実装順は認証基盤の成熟度を見て判断する

## 次アクション

1. ISSUE-045でauth session/revocation/keyring backend foundationを実装する。
2. ISSUE-046でsession APIsとFrontend再ログイン導線を実装する。
3. ISSUE-047でJWT key rotation staging smokeとproduction runbook gateを整備する。
4. ISSUE-048でworkflow endpointsのauth coverage gapを解消する。

## クローズ確認

- GitHub Issue: CLOSED
- PR: #49 merged
- CI: `verify` success
- 確認日時: 2026-07-06 06:44:06 JST
