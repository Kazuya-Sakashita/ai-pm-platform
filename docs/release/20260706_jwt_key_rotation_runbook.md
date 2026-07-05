# JWT key rotation and revocation runbook

## Purpose

JWT signing key rotation and token/session revocation must be repeatable, auditable, and safe under both normal maintenance and emergency compromise.

Related issues:

- ISSUE-042
- ISSUE-047

Related ADR: `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## Secret Handling

Never store or paste these values in Git, GitHub Issues, PR comments, screenshots, logs, AI chat, or support tickets:

- raw JWT
- JWT signing secret
- private key material
- raw `jti`
- refresh token
- production session export

Use the deployment secret store. The repository may contain only names, examples, and redacted evidence.

## Normal Rotation Preconditions

- New key exists in secret store with a unique `kid`.
- Old key remains verify-only during the overlap window.
- CI/CD validation confirms no duplicate `kid`, exactly one active key, no inline secret material, and valid rotation windows.
- Staging has passed dual-verify smoke.
- max access token TTL, clock skew, and deployment buffer are known.
- Rollback owner and approver are assigned.
- Monitoring for unknown/retired `kid` is available.

## Release Gate

Run the keyring validation gate before staging deploy, before production deploy, and before emergency key disable deploy.

### Staging rotation gate

Use a keyring file or deployment-generated JSON that contains the old verify-only key, the new active key, and any retired/disabled metadata. Do not place raw secrets in the JSON.

```bash
npm run jwt:keyring:validate -- \
  --file docs/release/examples/jwt-keyring.staging-smoke.example.json \
  --environment staging \
  --mode rotation
```

Expected:

- exit code is `0`
- exactly one active `kid`
- at least two currently usable verification keys
- `verify_only` keys have `retire_after`
- no inline `secret` values
- required `secret_env` variables exist in the runtime environment

CI validates the example fixture with dummy secret environment variables so the gate itself cannot silently break.

### Production steady-state gate

Run this in the production deploy environment where secret variables are already injected by the secret store:

```bash
npm run jwt:keyring:validate -- \
  --environment production \
  --mode steady
```

Expected:

- `AUTH_JWT_KEYRING_JSON` is present
- exactly one active `kid`
- every active or verify-only key uses `secret_env`
- referenced secret environment variables are present
- disabled/retired keys can exist without secret material

### Production rotation gate

During a planned rotation, production must pass rotation mode before deploying the signing switch:

```bash
npm run jwt:keyring:validate -- \
  --environment production \
  --mode rotation
```

Production rotation mode is a hard gate. Failure means the deploy must stop before traffic is shifted.

## Normal Rotation Steps

1. Create new signing key in secret store.
2. Add new `kid` to keyring as verify-capable but not active for signing.
3. Deploy to staging.
4. Run staging rotation gate.
5. Mint a token with old `kid` and confirm verification.
6. Mint a token with new `kid` and confirm verification.
7. Confirm `GET /api/v1/auth/sessions` succeeds with a session-backed token signed by the active key.
8. Promote new `kid` to active signing key.
9. Run production rotation gate.
10. Deploy to production in a low-traffic window.
11. Confirm new tokens carry the new `kid`.
12. Wait `max_access_token_ttl + clock_skew + deployment_buffer`.
13. Move old `kid` to retired.
14. Run production steady-state gate.
15. Confirm old tokens are rejected with `signing_key_retired`.
16. Save evidence in `docs/review/`.

## Staging Smoke Status

Current repository state as of 2026-07-06:

- Executable gate: implemented.
- CI fixture validation: implemented.
- Live staging smoke: waiting for a deployed staging environment with injected JWT secret store variables.

Until live staging exists, use `docs/review/20260706_jwt_key_rotation_staging_smoke_evidence_template.md` and mark `実施状況` as `未実施`. The blocker is acceptable only when the reason, owner, target environment URL, and next execution date are recorded.

## Rollback

Rollback is allowed only before the old key is retired.

1. Mark previous `kid` active for signing.
2. Keep the new `kid` verify-capable.
3. Deploy rollback.
4. Confirm auth success with previous key.
5. Record reason, approver, time window, and affected environment.

If the old key was retired because of compromise, do not roll back to it.

Rollback is prohibited when:

- previous `kid` is suspected or confirmed compromised
- previous `kid` has already been disabled
- previous `kid` secret has been deleted from the secret store
- old token usage shows abnormal replay, unknown geography, or automated abuse
- rollback would extend the old key beyond the documented `retire_after`

## Emergency Key Compromise

Use this path when a signing key may be exposed.

1. Disable compromised `kid` immediately.
2. Remove raw secret material for the compromised `kid` from deployable keyring JSON.
3. Run production steady-state gate. Disabled keys may remain as metadata without `secret_env`.
4. Deploy disabled keyring state.
5. Revoke all active sessions if token integrity is uncertain.
6. Temporarily pause high-risk operations if needed:
   - DM import creation
   - AI summary generation
   - deletion/anonymization
   - approval/publish actions
7. Force re-login for affected users.
8. Search logs/artifacts for raw token or secret exposure.
9. Record a critical `security_event`.
10. Save incident evidence with secrets redacted.

Expected emergency safe errors:

- disabled compromised key: `signing_key_not_active`
- retired non-compromised key after grace window: `signing_key_retired`
- unknown injected or forged `kid`: `signing_key_unknown`

## Session Revocation

### Current Session Logout

Expected:

- current `sid` becomes revoked
- current token returns `session_revoked`
- security event records safe metadata

### Device Revoke

Expected:

- selected `sid` becomes revoked
- other sessions remain active
- revoked session reuse returns `session_revoked`

### Logout Everywhere

Expected:

- all active sessions for actor become revoked
- actor `session_version` increments
- old tokens return `session_version_stale` or `session_revoked`

### Admin Forced Revoke

Expected:

- admin actor id and reason are recorded
- affected actor receives re-login requirement
- no raw token or private claim is exposed

## Evidence To Save

For normal rotation:

- datetime
- environment
- commit SHA
- previous `kid`
- new `kid`
- approver
- operator
- smoke result
- monitoring result
- rollback window
- conclusion
- gate command and result
- active `kid`
- verify-capable `kid` list
- disabled/retired `kid` list
- safe error code observed after retirement

For emergency:

- detection time
- affected `kid`
- suspected exposure source
- disabled time
- session revoke scope
- affected actor count
- paused operations
- recovery time
- follow-up issues
- gate command and result
- safe error code observed for disabled `kid`

## Monitoring And Alert Checklist

Monitor these before, during, and after rotation:

- `invalid_token` count by endpoint and environment
- `signing_key_unknown` count
- `signing_key_retired` count after grace window
- `signing_key_not_active` count for disabled/compromised `kid`
- `token_revoked`, `session_revoked`, `session_version_stale` counts
- auth latency p95/p99
- `authentication_not_configured` occurrence
- secret store read failures
- failed deploy preflight count

Alert immediately when:

- unknown `kid` spikes above baseline
- disabled key usage continues after emergency deploy
- retired key usage continues after grace window
- production reports `authentication_not_configured`
- secret store lookup fails in production
- auth p99 latency degrades during rotation

## Staging Smoke Evidence Template

Use `docs/review/20260706_jwt_key_rotation_staging_smoke_evidence_template.md`.

Evidence files must not contain raw JWTs, signing secrets, raw `jti`, session IDs, or full user-agent/IP values.

## Completion Criteria

Rotation or revocation is complete only when:

- expected safe error code is observed
- security event exists
- no secret appears in logs or artifacts
- monitoring is normal after the change
- review/evidence is saved under `docs/review/`
- GitHub Issue #47 has the final evidence and closure note
