# ADR-0017: JWT revocation/session version/key rotationを採用する

## Status

Accepted

## Date

2026-07-06

## Context

ADR-0016でAPI actor identityをBearer JWTの `sub` claimから導出する方針を採用した。これによりproduction pathで任意の `X-Actor-Id` を信頼しない状態へ進めた。

一方で、現行JWT verifierはHS256の単一secretを検証し、`sub`、`iss`、`aud`、`exp`、`nbf`、`iat` を確認するだけである。server-side session、`jti` denylist、session version、`kid` keyring、key rotation、auth lifecycle auditは未実装である。

AI PM PlatformはDM、会議、要件、Issue、AI生成、レビュー、削除、承認など高センシティブな操作を扱う。世界レベルSaaS基準では、漏えいtokenを期限切れまで放置する設計はenterprise trustの制約になる。

## Decision

短命access JWTに加えて、server-side auth session、session version、`jti` denylist、`kid` keyring、security event監査を採用する。

### JWT header

JWT headerは以下を必須にする。

- `alg`: 初期実装では `HS256`
- `typ`: `JWT`
- `kid`: keyring上の署名key id

`kid` がないtokenは移行期間のみfeature flagで許容する。production hardening完了後は拒否する。

### JWT claims

JWT claimsは以下を必須にする。

- `sub`: actor subject。ProjectMembershipの `actor_id` と照合する
- `sid`: auth session id
- `sv`: session version
- `jti`: token id
- `iss`: issuer
- `aud`: audience
- `iat`: issued at
- `nbf`: not before
- `exp`: expiration

production access token TTLは5分から15分を標準とし、verifierで最大TTLを強制する。長寿命のaccess JWTは許可しない。

### Server-side state

以下の永続モデルを導入する。

- `auth_actors`
  - `subject`
  - `status`
  - `session_version`
  - `sessions_revoked_at`
  - optional display/email fields
- `auth_sessions`
  - `sid`
  - `actor_subject`
  - `status`
  - `session_version`
  - `issued_at`
  - `expires_at`
  - `last_seen_at`
  - `revoked_at`
  - `revoked_by_actor_id`
  - `revocation_reason`
  - `ip_hash`
  - `user_agent_hash`
- `auth_token_revocations`
  - `jti_digest`
  - `sid`
  - `actor_subject`
  - `expires_at`
  - `reason`
- `security_events`
  - global auth/security audit events
  - project_id optional
  - safe metadata only

`AuditLog` はproject-scoped operation auditとして維持する。auth lifecycle、key rotation、rejected token、global session revokeは `security_events` に記録する。projectに紐づく操作中に発生したauth eventは、必要に応じて `project_id` を付与する。

### Revocation semantics

revocationは以下の粒度を持つ。

- current session revoke: `sid` を `revoked` にする
- device/session revoke: 対象 `sid` を `revoked` にする
- logout everywhere: actorのactive sessionsを失効し、`auth_actors.session_version` を増分する
- admin forced revoke: 管理者がactorまたはsessionを失効し、理由と実施者を `security_events` に記録する
- token-level incident revoke: `jti` のSHA-256 digestを `auth_token_revocations` に保存し、`exp` まで拒否する

raw JWT、raw `jti`、IPアドレス、User-Agent全文は保存しない。必要な場合はdigestまたは短い分類情報を保存する。

### Key rotation

`AUTH_JWT_SECRET` 単一secretからkeyringへ移行する。

keyringは以下を管理する。

- active signing key
- previous verify-only keys
- retired keys
- disabled keys
- key metadata: `kid`, algorithm, status, not_before, retire_after

通常rotation:

1. new keyをsecret storeへ追加する。
2. old/newをverify可能にしてdeployする。
3. signing keyをnew `kid` へ切り替える。
4. max access token TTL + clock skew + deployment bufferを待つ。
5. old keyをretiredへ移す。
6. rotation eventを `security_events` とrelease evidenceへ記録する。

緊急rotation:

1. compromised `kid` をdisabledへ移す。
2. 必要に応じて全sessionを失効する。
3. AI生成、DM import、削除、承認など高リスク操作を一時停止できるようにする。
4. 影響範囲と再ログイン要求を記録する。

## Rationale

- 漏えいtokenを期限切れ前に止められる。
- `sid` によりdevice/session単位の失効ができる。
- `session_version` によりlogout everywhereとglobal forced revokeが単純になる。
- `jti` denylistによりincident単位のtoken失効を表現できる。
- `kid` keyringにより通常rotationと緊急rotationを安全に分離できる。
- `security_events` によりproject外のauth lifecycleを監査できる。
- 将来RS256/JWKSや外部IdPへ移行しても、`sub/sid/jti/iss/aud/exp/kid` の考え方を維持できる。

## Alternatives Considered

### 短命JWTだけを継続する

不採用。

理由:

- 漏えいtokenを即時失効できない。
- logout everywhere、device revoke、admin forced revokeができない。
- key compromise時の封じ込めが弱い。

### `jti` denylistだけを導入する

不採用。

理由:

- token単位の失効はできるが、device単位やlogout everywhereが複雑になる。
- actor/session状態を表現できず、管理UIや監査に接続しにくい。

### session versionだけを導入する

不採用。

理由:

- logout everywhereには有効だが、単一device revokeや特定tokenのincident revokeが弱い。
- replay検知やtoken単位の拒否理由を記録しにくい。

### すぐに外部IdP/JWKSへ移行する

現時点では不採用。

理由:

- IdP選定、tenant、SSO、SCIM、組織管理までscopeが広がる。
- 内部session/revocation境界を固めてからIdPへ接続した方が安全である。

## Consequences

良い影響:

- token lifecycleを「発行」「利用」「失効」「rotation」「監査」まで扱える。
- security incident時に封じ込め手順を持てる。
- enterprise向けの監査説明がしやすくなる。
- Frontendの再ログイン、session一覧、device revoke UIへ拡張できる。

トレードオフ:

- auth stateがDB依存になるため、認証pathの可用性設計が必要になる。
- keyringとsession stateの実装、テスト、運用runbookが増える。
- access token検証が完全statelessではなくなる。
- `security_events` の保存期間と検索性を別途決める必要がある。

## Migration Plan

1. DB tablesとmodelsを追加し、runtime behaviorは変えない。
2. keyringを追加し、legacy `AUTH_JWT_SECRET` を一時互換で検証する。
3. `kid/sid/sv/jti` をoptional parseし、stagingで新claim tokenを検証する。
4. 保護済みendpointからsession checkを有効化する。
5. revoke APIs、request specs、security event specsを追加する。
6. staging/productionで `kid/sid/sv/jti` を必須化する。
7. older unauthenticated workflow endpointsのauth coverageを別Issueで閉じる。

## Safe Error Contract

401では以下のsafe error codeを使う。raw token、claims、secret、session metadataは返さない。

- `authentication_required`
- `authentication_not_configured`
- `invalid_token`
- `token_expired`
- `token_not_yet_valid`
- `token_revoked`
- `session_not_found`
- `session_expired`
- `session_revoked`
- `session_version_stale`
- `signing_key_unknown`
- `signing_key_retired`
- `signing_key_not_active`

Frontend表示は再ログインまたは管理者確認へ誘導する。token値や内部claimを表示しない。

## Follow-up Issues

- Auth session/revocation/keyring backend foundationを実装する。
- Auth session APIsとFrontend再ログイン導線を実装する。
- JWT key rotation staging smokeとproduction runbook gateを実装する。
- Older workflow endpointsのauth coverage gapを解消する。
