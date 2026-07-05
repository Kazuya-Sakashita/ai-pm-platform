# JWT revocation/session/key rotation security design

## 目的

ISSUE-042の設計成果として、JWT actor identityをproduction trustへ近づけるためのtoken失効、session管理、key rotation、監査、Frontend影響を定義する。

関連ADR:

- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`
- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## 現状

- APIはBearer JWTを検証し、`sub` をactor idとして扱う。
- Rails session/cookie authは使っていない。
- `X-Actor-Id` fallbackはproductionでは無効で、development/test向け互換である。
- `project_memberships.actor_id` が現時点のauthorization subjectである。
- user/session table、`jti` denylist、keyring、security event tableは未実装である。

## Threat Model

| STRIDE | リスク | 現状 | 設計対応 |
| --- | --- | --- | --- |
| Spoofing | 漏えいtokenの期限内再利用 | `exp` まで利用可能 | `sid` revoke、`jti` denylist、session version |
| Tampering | keyring設定改ざん | 単一secretのみ | `kid`、status、CI/CD validation、rotation evidence |
| Repudiation | 誰がsession/keyを失効したか追えない | project AuditLogのみ | global `security_events` |
| Information Disclosure | token/claim/secretがログやUIへ出る | safe error中心だが未網羅 | raw token保存禁止、safe error contract |
| Denial of Service | session store障害で全API停止 | 未設計 | fail closed、health/alert、incident runbook |
| Elevation of Privilege | admin token漏えい時に即時停止不可 | membership revokeのみ | admin forced revoke、logout everywhere |

## Data Model Draft

### auth_actors

`auth_actors` は認証subjectのglobal状態を表す。

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | primary key |
| subject | string | unique, JWT `sub` |
| status | string | active, suspended, disabled |
| session_version | integer | logout everywhereでincrement |
| sessions_revoked_at | datetime | 全session失効基準時刻 |
| display_name | string | optional |
| email_digest | string | optional, raw email保存は別判断 |
| created_at/updated_at | datetime | standard |

### auth_sessions

`auth_sessions` はdevice/session単位の状態を表す。

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | primary key |
| sid | string | unique, JWT `sid` |
| actor_subject | string | indexed |
| status | string | active, revoked, expired |
| session_version | integer | JWT `sv` と照合 |
| issued_at | datetime | token family start |
| expires_at | datetime | session lifetime |
| last_seen_at | datetime | optional throttle update |
| revoked_at | datetime | revoke timestamp |
| revoked_by_actor_id | string | safe actor id |
| revocation_reason | string | safe reason enum |
| ip_hash | string | raw IPは保存しない |
| user_agent_hash | string | raw UAは保存しない |
| created_at/updated_at | datetime | standard |

### auth_token_revocations

`auth_token_revocations` はtoken単位のdenylistである。

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | primary key |
| jti_digest | string | unique, SHA-256 digest |
| sid | string | indexed |
| actor_subject | string | indexed |
| expires_at | datetime | TTL cleanup boundary |
| reason | string | logout, incident, replay_suspected, admin_forced |
| created_by_actor_id | string | nullable system/admin |
| created_at | datetime | standard |

### security_events

`security_events` はauth lifecycleとkey operationのglobal auditである。

| Column | Type | Notes |
| --- | --- | --- |
| id | uuid | primary key |
| actor_id | string | operator or affected actor |
| project_id | uuid | optional |
| action | string | auth.session.revoked, auth.key.rotated, auth.token.rejected |
| target_type | string | auth_session, auth_actor, jwt_key, token |
| target_id | string | sid, subject, kid, jti_digest prefix |
| severity | string | info, warning, critical |
| summary | string | safe human summary |
| metadata | jsonb | safe metadata only |
| created_at | datetime | standard |

## JWT Contract

Required header:

```json
{
  "alg": "HS256",
  "typ": "JWT",
  "kid": "jwt-2026-07-a"
}
```

Required payload:

```json
{
  "sub": "actor-123",
  "sid": "session-uuid",
  "sv": 3,
  "jti": "token-uuid",
  "iss": "ai-pm-platform",
  "aud": "ai-pm-platform-api",
  "iat": 1783317600,
  "nbf": 1783317600,
  "exp": 1783318500
}
```

Production rules:

- `exp - iat` must be within configured max access token TTL.
- `kid` must exist and be active or verify-only.
- retired/disabled keys are rejected.
- `sid` must exist and be active.
- `sv` must match the actor/session version.
- `jti_digest` must not exist in `auth_token_revocations`.

## Authentication Flow

1. Parse Authorization header.
2. Decode JWT header without trusting payload.
3. Resolve `kid` through keyring.
4. Verify signature and standard claims.
5. Validate required lifecycle claims: `sid`, `sv`, `jti`.
6. Hash `jti` and check token denylist.
7. Load `auth_session` and `auth_actor`.
8. Reject revoked, expired, suspended, disabled, stale version states.
9. Return `actor_id`, `sid`, `jti_digest`, and safe claims to controller context.
10. Record high-risk rejected attempts as `security_events` with rate control.

## Safe Error Contract

| Code | HTTP | Message | Frontend action |
| --- | --- | --- | --- |
| authentication_required | 401 | Authentication is required. | login required |
| authentication_not_configured | 503 | Authentication is not configured. | admin contact |
| invalid_token | 401 | Authentication token is invalid. | clear token and login |
| token_expired | 401 | Authentication token has expired. | refresh/login |
| token_not_yet_valid | 401 | Authentication token is not active yet. | clock/login guidance |
| token_revoked | 401 | Authentication token has been revoked. | clear token and login |
| session_not_found | 401 | Authentication session was not found. | clear token and login |
| session_expired | 401 | Authentication session has expired. | login |
| session_revoked | 401 | Authentication session has been revoked. | login |
| session_version_stale | 401 | Authentication session is no longer current. | login everywhere |
| signing_key_unknown | 401 | Authentication token key is unknown. | login |
| signing_key_retired | 401 | Authentication token key has been retired. | login |
| signing_key_not_active | 401 | Authentication token key is not active. | login |

## Monitoring

必須メトリクス:

- invalid token count by code
- unknown `kid` count
- retired/disabled key usage count
- revoked session usage count
- `jti` denylist hit count
- session store unavailable count
- auth latency p95/p99

Alert candidates:

- unknown `kid` spike
- retired key usage after grace window
- token revoked usage spike
- auth store failure
- production `authentication_not_configured`
- legacy actor header enabled outside local development

## Acceptance Criteria

- OpenAPIにauth error code契約がある。
- ADRで `kid/sid/sv/jti` とkeyring/session stateを採用している。
- raw token、raw `jti`、secretをDB/log/UIへ保存しない方針がある。
- logout everywhere、device revoke、admin forced revoke、emergency key disableの挙動が定義されている。
- `security_events` とproject `AuditLog` の責務分離が定義されている。
- 実装IssueがDB/API/Frontend/Runbook/Auth coverageへ分解されている。

## 未完了

- DB migrationとmodelsは未実装。
- keyring parser/verifierは未実装。
- session revoke APIsは未実装。
- Frontendの実session UIは未実装。
- staging/production rotation smokeは未実施。
- 古いworkflow endpointsのauth coverage gapは別Issueで対応する。
