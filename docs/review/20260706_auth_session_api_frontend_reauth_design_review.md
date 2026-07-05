# Auth session API / Frontend reauth design review

## 評価日時

2026-07-06 07:18:00 JST

## 評価担当

Codex Review Orchestrator / Product Manager / Security Engineer / Backend Architect / Frontend Architect / QA / UI/UX Designer

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010

## Issue番号

ISSUE-046

## 評価対象

- `docs/issue/ISSUE-046_auth_session_api_frontend_reauth.md`
- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`
- `docs/security/20260706_jwt_revocation_session_key_rotation_design.md`
- `docs/api/openapi.yaml`
- `backend/app/models/auth_actor.rb`
- `backend/app/models/auth_session.rb`
- `backend/app/models/auth_token_revocation.rb`
- `backend/app/models/security_event.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/lib/api/client.ts`
- `frontend/lib/display-labels.ts`

## 良かった点

- ISSUE-045でsession state、token denylist、keyring、security eventのbackend foundationが入り、ISSUE-046でAPI/UXを薄く載せられる。
- safe auth error contractがOpenAPIとFrontend表示ラベルにすでに定義されており、再ログイン導線の判断材料がある。
- 既存Frontendはワークスペース内に運用、メンバー、GitHub連携の管理パネルがあり、セッション管理UIを同じ情報設計に自然に追加できる。
- `current_actor_id` contractが維持されているため、既存controllerを広範囲に変更せずにsession APIを追加できる。

## 改善点

- current session logout、session list、device revoke、logout everywhereのOpenAPI contractが未定義である。
- Frontend API clientは401/503 auth errorを共通処理せず、各API呼び出しの個別エラーとして扱うため、失効時に安全なstate clearへつながらない。
- login画面やexternal IdPが非スコープのため、再ログイン導線は「認証状態をクリアして再確認する」最小UXに限定される。将来のIdP接続時に差し替えやすくする必要がある。
- admin forced revokeは必要な運用機能だが、現時点ではglobal admin/organization role modelがない。public APIとして出すと横断的なsession失効権限が過剰になる。
- session listで `sid`、`actor_subject`、`ip_hash`、`user_agent_hash`、raw `jti` を返すと情報漏えい面が弱くなる。

## 改善案

- OpenAPIに以下を追加する。
  - `GET /auth/sessions`: current actorのsafe session list
  - `DELETE /auth/sessions/current`: current session logout
  - `DELETE /auth/sessions/{auth_session_id}`: own device/session revoke
  - `POST /auth/logout-everywhere`: own active sessions revoke + session version increment
- APIレスポンスは `AuthSession` safe viewに限定し、`id`、`status`、`current`、`issued_at`、`expires_at`、`last_seen_at`、`revoked_at`、`revocation_reason`、`created_at`、`updated_at` のみ返す。
- Frontend API clientのmiddlewareでauth clear対象codeを検知し、local auth stateをclearして `auth-required` eventを発火する。
- UIは左レールに「ログインセッション」パネルを追加し、現在のセッション、他デバイス失効、全セッション終了を操作できるようにする。
- admin forced revokeはISSUE-046ではpublic API化しない。`SecurityEvent` reason/actionとrunbookで扱いを定義し、organization/global admin model追加後に別IssueでAPI化する。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | 失効後にFrontendがtokenを使い続ける | API client middlewareでauth clear eventを追加 |
| P1 | self-service session revokeがない | current/device/logout everywhere APIを追加 |
| P1 | session listで内部IDやraw metadataを漏らす | safe serializerで `sid` / hash / raw token / raw jtiを返さない |
| P2 | admin forced revoke APIが未定義 | 現時点ではpublic API化しない判断をレビューへ保存 |
| P2 | IdP loginがない | 再ログイン導線は差し替え可能な最小UXに限定 |

## 次アクション

1. OpenAPIへAuth session contractを追加する。
2. Backend controller/service/request specsを追加する。
3. Frontend API client middlewareとセッション管理UIを追加する。
4. revoked/expired/stale/key retired時のUI復旧導線をPlaywrightで検証する。
5. 実装レビューを `docs/review/` に保存し、ISSUE-046へ結果を追記する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 失効/期限切れ/rotation後もユーザーが安全に復旧できるauth session UXを作る |
| Strategy | self-service session APIとFrontend共通auth error handlingを追加する |
| Tactics | OpenAPI first、safe serializer、SecurityEvent、middleware event、セッション管理パネル、request/E2E specs |
| Assessment | 実装に進んでよいが、admin forced revokeは権限モデル不足のためpublic API化しない |
| Conclusion | ISSUE-046はself-service session managementとreauth UXに限定する |
| Knowledge | 認証失効時は「便利なfallback」より「明示的な再認証要求」を優先する |

## STRIDE

| Threat | 設計対応 |
| --- | --- |
| Spoofing | session revoke後のtokenはDB stateで拒否し、Frontendはlocal auth stateをclearする |
| Tampering | session revoke対象はcurrent actor所有sessionに限定する |
| Repudiation | `security_events` にsession revoke/logout everywhereをsafe metadataで記録する |
| Information Disclosure | APIはraw token、raw `jti`、`sid`、IP/User-Agent hashを返さない |
| Denial of Service | logout everywhereは自分のactor scopeに限定し、global revokeはpublic API化しない |
| Elevation of Privilege | admin forced revokeはglobal admin modelができるまでrunbook/internal operation扱いにする |

## WCAG / UX

- 失効時の通知は `role="alert"` で画面上部に表示する。
- セッション失効ボタンは現在/他デバイス/全セッションで文言を分け、誤操作を確認する。
- 日本語表示は既存の `display-labels.ts` に寄せ、内部codeやclaim名を利用者へ露出しない。

## 判定

条件付き合格。

OpenAPI contract、Backend safe authorization、Frontend共通auth clear、E2E検証を満たす範囲で実装へ進む。admin forced revokeのpublic API化は本Issueでは見送る。
