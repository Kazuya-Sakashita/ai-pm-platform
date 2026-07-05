# ISSUE-042: JWT revocation/session version/key rotationを設計する

## Issue番号

ISSUE-042

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/42

登録日: 2026-07-05

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

## 関連ADR

- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`

## レビュー結果

ISSUE-039の実装レビューでは、P0の `X-Actor-Id` spoofing排除とAuditLog actor mappingは完了した。一方で、revocation/session version/key rotationは短命Bearer tokenとしてリスク受容しており、production trustをさらに上げるには後続設計が必要と判定した。

## 優先度

P1

理由:

- 漏えいtokenの即時失効ができない状態はenterprise trustの制約になる
- AI操作、DM整理、承認、削除の監査証跡と強く関係する
- 本格IdP/JWKSやSSOへ進む前に、内部session/tokenモデルの失効境界を決める必要がある
- ISSUE-040のmembership管理API/UIと並行して設計可能だが、実装順は認証基盤の成熟度を見て判断する

## 次アクション

1. Security Engineer AgentとBackend Architect Agentでrevocation方式を比較する。
2. ADRでsession version、`jti`、key rotation、短命token運用の採用/不採用を判断する。
3. OpenAPIの失効エラーcontractを設計する。
4. 必要に応じて実装Issueへ分解する。
