# Project membership management design review

## 評価日時

2026-07-05 20:07:29 JST

## 評価担当

Codex as Review Orchestrator / Security Engineer / QA / Backend Architect / Frontend Architect / UX Designer / Tech Lead

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DDD
- OpenAPI
- WCAG
- ISO25010

## Issue番号

- ISSUE-040
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/40

## 評価対象

- `docs/issue/ISSUE-040_project_membership_management_api_ui.md`
- `backend/app/models/project_membership.rb`
- `backend/app/controllers/application_controller.rb`
- `backend/app/controllers/api/v1/projects_controller.rb`
- `backend/app/controllers/api/v1/audit_logs_controller.rb`
- `docs/api/openapi.yaml`
- `frontend/app/workspace-client.tsx`
- `frontend/lib/display-labels.ts`

## 参加Agent

| Agent | Mode | 判定 |
| --- | --- | --- |
| Security Engineer + QA Agent | Codex subagent Averroes | 条件付き不合格 |
| Backend + Frontend + UX Agent | Codex subagent Hume | 条件付き合格 |
| Review Orchestrator | Codex primary | action_required before implementation |

## 良かった点

- `project_memberships` は `actor_id`、`role`、`status` の最小構造であり、ISSUE-040のMVP scopeに適している。
- ISSUE-039でJWT actor identityとProject最小認可が入り、membership管理APIの前提が整った。
- 既存のAuditLogがあり、membership作成、role変更、失効を監査証跡として残せる。
- Frontendはプロジェクト選択パネルがあり、同じ導線にメンバー管理を追加しやすい。

## 改善点

- `AuditLogsController#index` が未認可であり、membership管理UIから監査確認を出す前に必ず塞ぐ必要がある。
- OpenAPIにmembership管理API、401/403/409、schemaがまだない。
- 最後のactive ownerをrole変更・失効できると、Projectが管理不能になる。
- `project_id + actor_id` unique制約があるため、revoked済みactorの再追加方針を明確にする必要がある。
- AuditLog metadataにrequest paramsや自由入力を保存すると、secretや個人情報が漏れる可能性がある。
- owner権限の付与、owner降格、owner失効をadminに許すと権限昇格リスクがある。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P0 | AuditLog APIを認可する | ISSUE-040内で対応 |
| P0 | owner/adminのみmembership管理を許可する | ISSUE-040内で対応 |
| P0 | owner roleの付与/降格/失効はownerのみ許可する | ISSUE-040内で対応 |
| P0 | last owner protectionをtransaction + lockで実装する | ISSUE-040内で対応 |
| P0 | target membershipをproject scopedに取得する | ISSUE-040内で対応 |
| P0 | AuditLog metadataをallowlist化する | ISSUE-040内で対応 |
| P1 | Frontendに最小メンバー管理UIを追加する | ISSUE-040内で対応 |
| P1 | revoked済みactorの再追加方針を固定する | 初期実装では422で拒否 |

## 次アクション

1. OpenAPIに `ProjectMemberships` tag、paths、schemas、409 responseを追加する。
2. Audit logs endpointに401/403を追加する。
3. request specでowner/admin許可、role別拒否、cross-project拒否、last owner、safe metadataを先に固定する。
4. Backend controller/serviceでproject-scoped操作とAuditLog allowlistを実装する。
5. Frontendに一覧、追加、role変更、失効の最小UIを追加する。
6. 実装レビューを `docs/review/` に保存する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Project membershipを安全に追加、変更、失効し、監査可能にする |
| Strategy | OpenAPI-firstでAPI契約を固定し、last ownerとAuditLog認可をP0として実装する |
| Tactics | owner/admin guard、owner-only owner role操作、transaction lock、safe metadata、Frontend最小UI |
| Assessment | #40は実装へ進めてよいが、AuditLog API認可抜けを同時に塞がないと不合格 |
| Conclusion | P0条件を実装条件に組み込み、API駆動で進める |
| Knowledge | 権限管理は「付与できる」だけでは不十分で、誤付与、失効不能、監査漏れを同時に防ぐ必要がある |

## STRIDE / OWASP観点

| 観点 | リスク | 対応 |
| --- | --- | --- |
| Spoofing | JWT subject以外のactorによる操作 | `current_actor_id` とproject membershipで判定 |
| Tampering | 他project membership idの直接操作 | `project.project_memberships.find` に限定 |
| Repudiation | role変更/失効の監査不足 | AuditLogにsafe metadataを保存 |
| Information Disclosure | AuditLog未認可、metadata漏えい | AuditLog API認可、metadata allowlist |
| Elevation of Privilege | adminがowner付与できる | owner role操作はownerのみ |
| OWASP A01 | Broken Access Control | owner/admin guard、role別403 |
| OWASP A07 | Identification and Authentication Failures | JWT actor identity前提で操作 |
| OWASP A09 | Security Logging and Monitoring Failures | membership操作をAuditLogへ保存 |

## 判定

条件付き合格。ISSUE-040は実装へ進める。ただし、AuditLog API認可、last owner protection、owner-only owner role操作、project-scoped target lookup、safe metadataを満たさない場合は完了不可。

## AIレビュー比較

Codex primary、Codex subagent Averroes、Codex subagent Humeの指摘を統合した。両subagentはAuditLog API未認可をP0として一致。Averroesはtransaction lockとsafe metadataを強く指摘し、HumeはOpenAPI設計とFrontend最小UIを整理した。衝突はなく、両方の指摘を採用する。Claude、ChatGPTなど外部AIレビューは未実施。
