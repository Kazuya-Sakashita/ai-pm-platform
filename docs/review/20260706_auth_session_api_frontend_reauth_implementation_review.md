# Auth session API / Frontend reauth implementation review

## 評価日時

2026-07-06 07:18:31 JST

## 評価担当

Codex Review Orchestrator / Security Engineer / Backend Architect / Frontend Architect / QA / UI/UX Designer

Subagents:

- Backend/Auth/Security Agent: Wegener
- Frontend Architect / UI/UX / QA Agent: Popper

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- WCAG
- HEART
- ISO25010

## Issue番号

ISSUE-046

## 評価対象

- `docs/api/openapi.yaml`
- `backend/app/controllers/api/v1/auth_sessions_controller.rb`
- `backend/app/services/authentication/session_revocation_service.rb`
- `backend/app/models/auth_session.rb`
- `backend/config/routes.rb`
- `backend/spec/requests/api/v1/auth_sessions_spec.rb`
- `frontend/lib/api/client.ts`
- `frontend/app/workspace-client.tsx`
- `frontend/app/globals.css`
- `frontend/lib/display-labels.ts`
- `frontend/e2e/auth-session.spec.ts`
- `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- OpenAPIに `GET /auth/sessions`、`DELETE /auth/sessions/current`、`DELETE /auth/sessions/{auth_session_id}`、`POST /auth/logout-everywhere` を追加し、contract firstで実装した。
- Auth session APIはsession-backed JWTを必須にし、legacy `X-Actor-Id` や `sid/sv/jti` なしJWTでは `invalid_token` で拒否する。
- session list responseはsafe viewに限定し、`sid`、raw `jti`、`jti_digest`、IP hash、User-Agent hash、signing metadataを返さない。
- current logout、other device revoke、logout everywhereを `security_events` にsafe metadataで記録する。
- Frontend API client middlewareでauth terminal error codeを共通検知し、local auth stateをclearして再ログインイベントを発火できる。
- Frontendはauth lock時に会議、DM、Issue、OpenAPIなどのserver由来/入力中stateをclearし、通常ワークスペースを描画しない。
- background requestの401でもauth lockへ遷移し、in-flight成功レスポンスが機密stateを再投入しないguardを追加した。
- Playwrightで初回401、background401、session list、other session revoke、current logout、mobile overflowを検証した。

## 改善点

- 実際のrefresh token / IdP loginは非スコープのため、再ログインCTAは現時点ではlocal/demo auth state再確認に留まる。
- `AuthSession` safe viewにはdevice labelがないため、複数端末の識別性はまだ弱い。将来はraw UAではなく粗いdevice labelを保存する設計が必要である。
- `logout_everywhere` はactive sessionを順次updateしており、session数が多いenterprise tenantではbulk updateとevent粒度の再検討が必要である。
- admin forced revokeはglobal admin/organization role modelがないためpublic API化していない。運用要件としては後続Issueが必要である。
- auth lock UIはワークスペース内で完結しており、専用ログイン画面やIdP redirectとは未接続である。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | IdP/refresh tokenなしの再ログインCTA | 後続Auth issuer/IdP Issueで対応 |
| P1 | admin forced revokeの権限モデル未定義 | platform admin / organization modelのADRとIssueへ分離 |
| P2 | device識別が弱い | raw UAを保存しないdevice label設計を追加 |
| P2 | high-volume session revoke最適化 | enterprise運用時にbulk update/監査粒度を再評価 |
| P2 | `AUTH_JWT_REQUIRE_SESSION_CLAIMS` production必須化 | ISSUE-047のrunbook/gateと接続 |

## 次アクション

1. PRを作成し、CI成功後にマージする。
2. ISSUE-046をGitHub上でクローズする。
3. 次はISSUE-047でJWT key rotation staging smoke / production runbook gateを整備する。
4. その後ISSUE-048でolder workflow endpoint auth coverage gapを閉じる。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/auth_sessions_spec.rb spec/requests/api/v1/authentication_session_spec.rb`: 8 examples, 0 failures
- `bundle exec rspec spec/requests/api/v1/auth_sessions_spec.rb spec/requests/api/v1/authentication_session_spec.rb spec/services/authentication/jwt_verifier_spec.rb spec/models/authentication_foundation_spec.rb`: 27 examples, 0 failures
- `bundle exec rspec`: 244 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/auth-session.spec.ts`: 3 passed
- `npm run frontend:e2e`: 29 passed

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 失効/期限切れ/rotation後に安全に復旧できるsession APIとFrontend導線を作る |
| Strategy | self-service session managementとFrontend共通auth terminal handlingを追加 |
| Tactics | OpenAPI first、session-backed JWT必須、safe serializer、SecurityEvent、API middleware、auth lock panel、E2E |
| Assessment | ISSUE-046のMVP要件は満たした。IdP/refresh/admin global revokeは後続が必要 |
| Conclusion | PR化してよい |
| Knowledge | auth失効時はエラー表示だけでなく、機密stateを明示的にclearし通常UIを描画しないことが重要 |

## STRIDE

| Threat | 実装対応 |
| --- | --- |
| Spoofing | session APIはsession-backed JWT必須、legacy header不可 |
| Tampering | revoke対象はcurrent actor所有sessionに限定 |
| Repudiation | `security_events` へsession revoke/logout everywhereを記録 |
| Information Disclosure | response/security metadataからraw token/raw jti/sid/IP hash/UA hashを排除 |
| Denial of Service | logout everywhereを本人scopeへ限定し、admin global revokeは未公開 |
| Elevation of Privilege | project admin権限でglobal auth sessionを失効できない |

## AIレビュー比較

Backend/Auth/Security Agent Wegenerは、session claimなしJWTでsession APIsが使えるとdevice revoke/logout everywhereを回避できる点をP0として指摘した。実装では `require_session_actor!` を追加し、`current_auth_context.auth_session` と `jti_digest` がない場合は `invalid_token` で拒否した。

Frontend Architect / UI/UX / QA Agent Popperは、auth terminal error後もDM原文やIssueドラフトが画面に残る点をP0候補として指摘した。実装ではAPI middlewareから `authRequiredEventName` を発火し、ワークスペースstateをclearしたうえでauth lock panelだけを描画するようにした。

相違点:

- WegenerはBackendのsession-backed JWT必須化とsafe metadataを最重視した。
- PopperはFrontendの機密state clear、background 401、mobile/a11yを最重視した。

統合判断:

- 両方を採用し、session APIはlegacy fallback不可、Frontendはterminal auth errorを通常APIエラーとは別系統で扱う設計にした。
- admin forced revokeは必要性を認めつつ、global admin modelがないためISSUE-046ではpublic API化しない判断を採用した。

## 判定

合格。

ISSUE-046は完了可能。ただし、production-grade auth完成にはISSUE-047、ISSUE-048、IdP/refresh token/admin auth modelの後続対応が必要である。
