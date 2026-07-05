# Project membership management implementation review

## 評価日時

2026-07-06 04:54:49 JST

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

- `docs/api/openapi.yaml`
- `backend/app/controllers/api/v1/project_memberships_controller.rb`
- `backend/app/services/project_memberships/management_service.rb`
- `backend/app/models/project_membership.rb`
- `backend/app/controllers/api/v1/audit_logs_controller.rb`
- `backend/spec/requests/api/v1/project_memberships_spec.rb`
- `backend/spec/requests/api/v1/audit_logs_spec.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`
- `frontend/lib/display-labels.ts`

## 参加Agent

| Agent | Mode | 判定 |
| --- | --- | --- |
| Security Engineer + QA Agent | Codex subagent Averroes | 条件付き合格 |
| Backend + Frontend + UX Agent | Codex subagent Hume | 条件付き合格 |
| Review Orchestrator | Codex primary | 合格 |

## 良かった点

- OpenAPIに `ProjectMemberships` API、schema、401/403/409/422を追加し、生成型を同期した。
- owner/adminのみがmembership一覧、追加、role変更、失効を行える。
- owner roleの付与、owner降格、owner失効はownerのみに制限した。
- 最後のactive ownerの降格/失効を409 `last_owner_required` で拒否し、transaction内でmembershipをlockする実装にした。
- target membershipは `project.project_memberships.find` で取得し、他projectのmembership IDを直接操作できない。
- membership作成、role変更、失効をAuditLogへ記録し、metadataは `membership_id`、`target_actor_id`、role/status before/afterに限定した。
- AuditLog APIにProject read認可を追加し、監査ログの未認可閲覧を塞いだ。
- Frontendにメンバー管理パネルを追加し、一覧、追加、role変更、失効を日本語UIで操作できるようにした。

## 改善点

- actor_idは文字列入力であり、ユーザー検索、表示名、メール招待、ディレクトリ連携はまだない。
- revoked済みactorの再有効化は初期実装では422拒否にしており、復帰フローは未実装である。
- owner移譲ウィザード、bulk import、詳細権限マトリクス、組織管理は未実装である。
- Frontend側の操作可否disableは最小で、最終的な権限判定はBackendに依存する。
- Meetings/IntegrationsなどProject配下API全体へのauthorization拡張は、ISSUE-040の主対象外として残る。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P0 | AuditLog API未認可 | ISSUE-040で対応 |
| P0 | owner/admin以外のmembership管理拒否 | ISSUE-040で対応 |
| P0 | owner role操作のowner限定 | ISSUE-040で対応 |
| P0 | last owner protection | ISSUE-040で対応 |
| P0 | safe AuditLog metadata | ISSUE-040で対応 |
| P1 | actor directory/search/invite | 後続Issue候補 |
| P1 | revoked membership reactivation | 後続Issue候補 |

## 次アクション

1. ISSUE-040のGitHub Issueへ実装結果と検証結果を同期する。
2. PRを作成し、CI成功後にマージする。
3. マージ後にGitHub Issue #40をクローズする。
4. 次はISSUE-042またはISSUE-037/036の優先順位を再評価する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Project membershipを安全に管理し、監査可能にする |
| Strategy | OpenAPI-first、Backend強制認可、Frontend最小UI、Security/UX reviewを通す |
| Tactics | owner/admin guard、owner-only owner操作、last owner 409、AuditLog allowlist、E2E UI smoke |
| Assessment | P0条件は満たした。ユーザー検索/招待/再有効化は後続でよい |
| Conclusion | ISSUE-040はCI通過を条件に完了可能 |
| Knowledge | AI PMの権限管理は、AI操作の信頼性と監査可能性を支える基礎機能である |

## STRIDE / OWASP観点

| 観点 | 評価 | 対応状況 |
| --- | --- | --- |
| Spoofing | JWT actor identityとactive membershipで操作主体を確認 | 対応済み |
| Tampering | 他project membership IDの直接操作をproject scopeで防止 | 対応済み |
| Repudiation | membership変更をAuditLogへ保存 | 対応済み |
| Information Disclosure | AuditLog APIへProject read認可を追加 | 対応済み |
| Elevation of Privilege | adminのowner付与/降格/失効を禁止 | 対応済み |
| OWASP A01 | Broken Access Control | role別request specで固定 |
| OWASP A09 | Security Logging and Monitoring Failures | safe metadataで監査記録 |

## 検証結果

- `bundle exec rspec`: 222 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: success
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 26 passed

## 判定

合格。ISSUE-040の完了条件であるOpenAPI契約、owner/admin管理、last owner protection、role別拒否、cross-project拒否、AuditLog safe metadata、Frontend最小UI、Security/UXレビュー保存を満たした。

## AIレビュー比較

Codex primary、Codex subagent Averroes、Codex subagent Humeの指摘を統合した。AverroesはSecurity/QA観点でAuditLog未認可、transaction lock、safe metadataをP0とし、HumeはOpenAPIとUXの最小実装を提案した。衝突はなく、両方を採用した。Claude、ChatGPTなど外部AIレビューは未実施。
