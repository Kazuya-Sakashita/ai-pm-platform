# JWT revocation/session/key rotation design review

## 評価日時

2026-07-06 06:35:03 JST

## 評価担当

Codex Review Orchestrator / Security Engineer / DevOps / Backend Architect / QA / Frontend Architect / Product Manager

Subagents:

- Security/DevOps Agent: Bohr
- Backend/Auth Architect Agent: Herschel

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- RICE
- DORA Metrics

## Issue番号

ISSUE-042

## 評価対象

- `backend/app/services/authentication/jwt_verifier.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/app/models/project_membership.rb`
- `backend/app/models/audit_log.rb`
- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`
- `docs/issue/ISSUE-042_jwt_revocation_session_key_rotation.md`
- `docs/api/openapi.yaml`

## 良かった点

- ADR-0016で `X-Actor-Id` production trustを排除済みで、actor identityの最初の境界は改善されている。
- JWT verifierは `iss/aud/exp/nbf/iat` を検証し、safe errorを返す設計になっている。
- ProjectMembership管理APIにより、project-level authorizationの運用導線が整い始めている。
- ISSUE-042がrevocation、session version、key rotationを独立Issueとして扱っており、scope膨張を避けている。

## 改善点

- 漏えいJWTは `exp` まで利用可能で、即時失効できない。
- `kid` がなく、HS256単一secret rotationがall-or-nothingになっている。
- `sid`、`sv`、`jti` がなく、device revoke、logout everywhere、token単位incident revokeができない。
- project-scoped `AuditLog` だけでは、global auth lifecycleやkey rotationを監査できない。
- OpenAPIの401 contractが汎用的で、revoked/session/key状態を安全に区別できない。
- Frontendは失効時の実session clear、再ログイン、再接続導線が未実装である。
- older workflow endpointsにauth coverage gapが残っている。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | `kid/sid/sv/jti` を含むJWT lifecycle contractを採用 | ADR-0017 |
| P1 | auth session/revocation/keyring DB foundationを実装 | 後続Issue |
| P1 | safe auth error codeをOpenAPIへ反映 | ISSUE-042 |
| P1 | security event監査を追加 | 後続Issue |
| P1 | key rotation runbookとstaging smokeを用意 | ISSUE-042と後続Issue |
| P2 | Frontend session expired/revoked導線を実装 | 後続Issue |
| P2 | older endpointのauth coverage gapを解消 | 後続Issue |

## 次アクション

1. ISSUE-045でauth session/revocation/keyring backend foundationを実装する。
2. ISSUE-046でsession APIsとFrontend再ログイン導線を実装する。
3. ISSUE-047でJWT key rotation staging smokeとproduction runbook gateを整備する。
4. ISSUE-048でworkflow endpointsのauth coverage gapを解消する。
5. 外部AIレビューが追加された場合は、session model、refresh token方針、JWKS移行方針の差分を比較する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | JWT actor identityをproduction運用に耐えるtoken lifecycleへ進める |
| Strategy | 短命JWT + server-side session + keyring + security eventで封じ込めと監査を両立する |
| Tactics | `kid/sid/sv/jti`、session state、denylist、rotation runbook、safe error contractを設計する |
| Assessment | P1として妥当。ただしenterprise trustでは実装前にproduction公開対象を制限すべき |
| Conclusion | ADR-0017の採用と後続実装Issue分割を承認 |
| Knowledge | 認証はtokenを受け入れる仕組みだけでなく、止める、戻す、監査する仕組みまで含めて完成する |

## STRIDE

| Threat | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 漏えいtoken再利用リスクが残る | `sid` revoke、`jti` denylist |
| Tampering | keyring改ざんリスク | CI/CD validation、rotation evidence |
| Repudiation | auth lifecycle操作の否認リスク | `security_events` |
| Information Disclosure | raw token/claim漏えいリスク | safe metadata、raw token保存禁止 |
| Denial of Service | auth store障害時の停止 | fail closed、monitoring、incident runbook |
| Elevation of Privilege | admin token漏えい時の即時停止不可 | admin forced revoke、logout everywhere |

## AIレビュー比較

Security/DevOps Agentは、key compromiseと漏えいtoken封じ込めを重視し、`kid` keyring、revocation monitoring、緊急rotation runbookをP1条件とした。

Backend/Auth Architect Agentは、現行Rails実装のblast radiusを重視し、`auth_actors`、`auth_sessions`、`auth_token_revocations`、`security_events` を段階導入するmigration planを提案した。

相違点:

- Security/DevOpsはoperational readinessを強く要求した。
- Backend/Authは既存endpointへの段階適用と互換feature flagを重視した。

統合判断:

- 両者の指摘は矛盾しない。ADRではSecurity/DevOpsのkeyring/incident要件を採用し、実装順はBackend/Authの段階migrationを採用する。
- 外部AIレビューは未実施。外部レビュー結果が追加された場合は、session model、refresh token方針、JWKS移行方針の差分を比較する。

## 判定

条件付き合格。

ISSUE-042の設計成果物としてADR、security design、runbook、OpenAPI safe error contractを保存すれば設計フェーズは完了可能。ただし、production-grade認証としては後続実装Issueが完了するまで未達である。

## 検証結果

- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `git diff --check`: success
