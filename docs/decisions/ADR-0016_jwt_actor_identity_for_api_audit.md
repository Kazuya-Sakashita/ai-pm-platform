# ADR-0016: JWTでAPI actor identityを確定する

## Status

Accepted

## Date

2026-07-05

## Context

ISSUE-030でDM系APIにproject membershipとPolicy Objectを導入したが、actor identityは `X-Actor-Id` headerから取得していた。これはMVP開発では便利だが、productionではクライアントが任意に偽装できるため、なりすまし、権限昇格、監査否認を防げない。

ISSUE-039では、DM本文、AI整理draft、承認、削除、AI送信の操作を、認証済みuser idへ接続する必要がある。ただし、SSO/SAML、SCIM、組織横断RBAC、外部IdP本番設定まで含めるとscopeが過大になる。

## Decision

API actor identityはBearer JWTから導出する。

初期実装ではHMAC-SHA256署名のJWTを検証し、`sub` claimをactor idとして扱う。DM系APIではproduction pathで `X-Actor-Id` を信頼しない。`X-Actor-Id` はdevelopment/testのlegacy helperとしてのみ残し、OpenAPIのproduction contractからは外す。

検証するclaim:

- `alg`: `HS256` のみ許可する
- `sub`: 必須。project membershipの `actor_id` と照合する
- `iss`: `AUTH_JWT_ISSUER`。defaultは `ai-pm-platform`
- `aud`: `AUTH_JWT_AUDIENCE`。defaultは `ai-pm-platform-api`
- `exp`: 必須。期限切れtokenは拒否する
- `nbf`: 任意。未来時刻なら拒否する
- `iat`: 任意。許容clock skewを超えて未来なら拒否する

clock skewは `AUTH_JWT_CLOCK_SKEW_SECONDS` で調整し、defaultは30秒とする。

local/testでは `AUTH_JWT_SECRET` が未設定の場合に限り、固定のdevelopment secretを使う。productionでは `AUTH_JWT_SECRET` を必須にし、未設定なら認証を失敗させる。

## Rationale

- `X-Actor-Id` 偽装をproduction pathから排除できる。
- OpenAPIの既存 `bearerAuth` security schemeと整合する。
- user/session tableをまだ導入していない段階でも、project membershipの `actor_id` と接続できる。
- SSO/SAMLを待たずにAuditLog actor_idを認証済みsubjectへ接続できる。
- HMAC JWTは依存gemを追加せず、Rails標準ライブラリで検証できる。

## Alternatives Considered

### `X-Actor-Id` を継続する

不採用。

理由:

- 任意headerなのでproductionでは偽装できる。
- AuditLogのactor_idを信頼できない。
- AI送信、削除、承認の監査証跡として弱い。

### Rails session cookieを先に導入する

現時点では不採用。

理由:

- API client、GitHub callback、将来のSlack/Discord bot連携ではBearer tokenの方が扱いやすい。
- Next.js frontendとRails APIが別originになる前提ではCORS、CSRF、cookie属性の設計が追加で必要になる。
- ISSUE-039ではactor identity境界を固定することを優先する。

### Devise/JWT gemを追加する

現時点では不採用。

理由:

- user model、password auth、refresh token、mail verificationまでscopeが広がる。
- 依存追加なしでJWT検証とAuditLog接続のP0 blockerは解消できる。
- 本格的なユーザー管理はSSO/IdP方針と合わせて別ADRで検討する。

### 外部IdP/JWKS検証をすぐ実装する

現時点では不採用。

理由:

- 外部IdP本番設定はISSUE-039の非スコープである。
- issuer/audience/expiry/subjectの契約を先に固定する方が安全である。
- 将来、RS256/JWKSへ移行する場合もOpenAPIのBearer contractは維持できる。

## Revocation / Replay stance

ISSUE-039では短命Bearer JWTを前提にし、server-side revocation listやsession version検証は実装しない。

受容理由:

- 現時点ではuser/session storeが存在しない。
- DM系APIのproduction blockerは「任意headerを信頼しないこと」である。
- token寿命を短くし、TLS、secret管理、AuditLogでリスクを下げる。

残リスク:

- 漏えいした有効期限内tokenは期限切れまで使える。
- 即時失効、logout everywhere、device単位失効はできない。

後続課題:

- session store、refresh token、jti revocation、external IdP/JWKS、key rotationを別Issueで扱う。

## Consequences

良い影響:

- DM系APIのactor identityが認証済みtoken subjectへ接続される。
- AuditLog actor_idがclient指定値ではなく検証済みsubjectになる。
- OpenAPIとFrontend clientをBearer JWT前提へ寄せられる。
- Security/QAが未認証、不正token、期限切れ、非member、role不足をrequest specで固定できる。

トレードオフ:

- local demoではauth token設定またはdevelopment legacy fallbackが必要になる。
- 本格的なsession失効、SSO/SAML、IdP連携はまだ未実装である。
- HMAC secretの安全なproduction配布、rotation、監査が必要になる。

## Follow-up

- ISSUE-039でJWT verifier、OpenAPI更新、request spec、Frontend auth headerを実装する。
- 後続Issueでtoken revocation/session version/key rotationを設計する。
- ISSUE-040でmembership管理API/UIを実装し、認証済みuser idに基づく権限運用へ接続する。
