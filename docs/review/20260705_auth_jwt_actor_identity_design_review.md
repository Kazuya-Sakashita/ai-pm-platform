# Auth JWT actor identity design review

## 評価日時

2026-07-05 17:55:00 JST

## 評価担当

Codex as Review Orchestrator / Security Engineer / QA / CTO / Tech Lead / Backend Architect / Frontend Architect / DevOps

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DDD
- OpenAPI
- ISO25010

## Issue番号

- ISSUE-039
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/39

## 評価対象

- `docs/issue/ISSUE-039_auth_jwt_actor_identity.md`
- `docs/review/20260705_expert_subagent_pilot_issue_039_review.md`
- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`
- `ApplicationController#current_actor_id`
- DM系APIの `X-Actor-Id` dependency
- `docs/api/openapi.yaml`
- `frontend/lib/api/client.ts`

## 参加Agent

| Agent | Mode | 判定 |
| --- | --- | --- |
| Security Engineer + QA Agent | Codex subagent Ramanujan | action_required |
| Backend + Frontend + Tech Lead Agent | Codex subagent Boole | action_required |
| Review Orchestrator | Codex primary | action_required before implementation |
| Backend/Frontend/DevOps role-separated experts | Codex primary | conditional_pass after ADR/OpenAPI/specs |

## 良かった点

- 既存のOpenAPIには `bearerAuth` security schemeがあり、JWT前提へ寄せる下地がある。
- Project membershipとPolicy Objectは実装済みのため、JWT `sub` を `project_memberships.actor_id` に接続すれば権限判定を再利用できる。
- AuditLogが既に存在し、actor_idを認証済みsubjectへ接続する価値が明確である。
- ISSUE-039の非スコープにSSO/SAML、SCIM、外部IdP本番設定が明記されており、scopeを抑えられる。

## 改善点

- 現状のproduction contractは `bearerAuth` と `X-Actor-Id` が混在しており、DM系APIでactor headerを要求している。
- `ApplicationController#current_actor_id` が `X-Actor-Id` を直接信頼している。
- Frontend API clientが `NEXT_PUBLIC_ACTOR_ID` から `X-Actor-Id` を送っている。
- request specはmembership failureを検証しているが、JWT missing/invalid/expired/not-yet-valid/wrong issuer/wrong audience/wrong algorithmをまだ検証していない。
- token revocation/replayはISSUE-039では未実装になるため、ADRで短命Bearer tokenとして明確にリスク受容する必要がある。
- Projects APIが未認証のままだとDM系APIのproject境界だけ固めても一覧/更新/削除側から権限境界が抜ける。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P0 | production pathで `X-Actor-Id` を信頼しない | ISSUE-039内で対応 |
| P0 | JWTのissuer/audience/alg/exp/nbf/iatを検証する | ISSUE-039内で対応 |
| P0 | AuditLog actor_idをJWT subjectへ接続する | ISSUE-039内で対応 |
| P0 | request specでJWT failure modeを固定する | ISSUE-039内で対応 |
| P1 | Frontend API clientがAuthorization headerを扱う | ISSUE-039内で対応 |
| P1 | Projects APIの最小actor境界を追加する | ISSUE-039内で対応 |
| P1 | token revocation/session version/key rotation | 後続Issue候補 |

## 次アクション

1. ADR-0016を保存する。
2. OpenAPIからDM系 `X-Actor-Id` parameterを外し、Bearer JWT contractへ統一する。
3. BackendにJWT verifierとauth contextを追加する。
4. request specでmissing/malformed/bad signature/expired/future nbf/wrong iss/wrong aud/wrong alg/spoof header/nonmember/role不足を検証する。
5. Frontend API clientへAuthorization headerと日本語再ログイン導線を追加する。
6. 実装後に専門家サブエージェントレビューを更新する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | `X-Actor-Id` 依存を解消し、DM系API操作を認証済みactorへ接続する |
| Strategy | ADR、OpenAPI、request specを先に固定し、最小JWT verifierで実装する |
| Tactics | HS256 JWT、issuer/audience/expiry検証、safe error、AuditLog actor mapping、Frontend Authorization |
| Assessment | 実装前条件は明確。revocation/replayは短命Bearer tokenとしてリスク受容し、後続Issueへ送る |
| Conclusion | ADR/OpenAPI/specsを作成したうえで実装へ進める |
| Knowledge | AI PMでは「AIが何を生成したか」だけでなく「誰の認証済み権限で操作されたか」が監査の基礎になる |

## STRIDE / OWASP観点

| 観点 | 現リスク | 対応 |
| --- | --- | --- |
| Spoofing | `X-Actor-Id` を任意指定できる | JWT subjectからactorを導出する |
| Tampering | `alg=none` や署名不一致を許すとtoken改ざん可能 | HS256 allowlistとHMAC検証 |
| Repudiation | AuditLog actor_idがclient入力に依存 | AuditLogへJWT subjectを保存 |
| Information Disclosure | auth errorにtoken/claim/DM本文が漏れる | safe error contractで詳細を返さない |
| Elevation of Privilege | spoofed owner headerで操作される | Authorization token subjectだけをPolicyに渡す |
| OWASP A01 | Broken Access Control | membership policyを認証済みactorへ接続 |
| OWASP A07 | Identification and Authentication Failures | expired/invalid/wrong issuer/audienceを401で拒否 |
| OWASP A09 | Security Logging and Monitoring Failures | AuditLog actor_idを検証済みsubjectへ接続 |

## 判定

条件付き合格。ADRとOpenAPI更新、JWT failure request specを先に入れることを条件に実装へ進める。Security/QA AgentのP0指摘は採用する。

## AIレビュー比較

Codex primary、Codex subagent Ramanujan、Codex subagent Booleによるレビューを反映した。RamanujanはSecurity/QA failure mode、BooleはProjects APIの未認証一覧/更新/削除とFrontend auth providerを重視した。BooleのProjects API指摘を追加scopeとして採用し、ISSUE-039内で最小限のproject membership境界を入れる方針に変更した。Claude、ChatGPTなど外部AIレビューは未実施。
