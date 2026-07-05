# JWT key rotation and revocation runbook

## Purpose

JWT signing key rotation and token/session revocation must be repeatable, auditable, and safe under both normal maintenance and emergency compromise.

Related issue: ISSUE-042

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
- CI/CD validation confirms no duplicate `kid`.
- Staging has passed dual-verify smoke.
- max access token TTL, clock skew, and deployment buffer are known.
- Rollback owner and approver are assigned.
- Monitoring for unknown/retired `kid` is available.

## Normal Rotation Steps

1. Create new signing key in secret store.
2. Add new `kid` to keyring as verify-capable but not active for signing.
3. Deploy to staging.
4. Mint a token with old `kid` and confirm verification.
5. Mint a token with new `kid` and confirm verification.
6. Promote new `kid` to active signing key.
7. Deploy to production in a low-traffic window.
8. Confirm new tokens carry the new `kid`.
9. Wait `max_access_token_ttl + clock_skew + deployment_buffer`.
10. Move old `kid` to retired.
11. Confirm old tokens are rejected with `signing_key_retired`.
12. Save evidence in `docs/review/`.

## Rollback

Rollback is allowed only before the old key is retired.

1. Mark previous `kid` active for signing.
2. Keep the new `kid` verify-capable.
3. Deploy rollback.
4. Confirm auth success with previous key.
5. Record reason, approver, time window, and affected environment.

If the old key was retired because of compromise, do not roll back to it.

## Emergency Key Compromise

Use this path when a signing key may be exposed.

1. Disable compromised `kid` immediately.
2. Deploy disabled keyring state.
3. Revoke all active sessions if token integrity is uncertain.
4. Temporarily pause high-risk operations if needed:
   - DM import creation
   - AI summary generation
   - deletion/anonymization
   - approval/publish actions
5. Force re-login for affected users.
6. Search logs/artifacts for raw token or secret exposure.
7. Record a critical `security_event`.
8. Save incident evidence with secrets redacted.

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

## Completion Criteria

Rotation or revocation is complete only when:

- expected safe error code is observed
- security event exists
- no secret appears in logs or artifacts
- monitoring is normal after the change
- review/evidence is saved under `docs/review/`
