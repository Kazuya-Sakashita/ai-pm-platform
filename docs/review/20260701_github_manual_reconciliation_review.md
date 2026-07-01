# 2026-07-01 GitHub Manual Reconciliation実装レビュー

## 評価日時

2026-07-01 18:51 JST

## 評価担当

Codex

- CTO
- Tech Lead
- Backend Architect
- Security Engineer
- QA
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- DDD

## 対象Issue

- ISSUE-004
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

## 対象成果物

- `backend/app/services/github_issue_publish/manual_reconciliation_service.rb`
- `backend/app/controllers/api/v1/issue_drafts_controller.rb`
- `backend/app/models/github_issue_publish_attempt.rb`
- `backend/app/services/github_issue_publish_service.rb`
- `docs/api/openapi.yaml`
- `frontend/lib/api/schema.d.ts`
- `backend/spec/services/github_issue_publish/manual_reconciliation_service_spec.rb`
- `backend/spec/requests/api/v1/issue_drafts_spec.rb`

## G-STACK

### Goal

GitHub Issue publish reconciliationの0件/複数件ケースに、人間レビュー後の安全な出口を作る。

### Strategy

`POST /issue-drafts/{issue_draft_id}/resolve-github-reconciliation` を追加し、`link_existing_issue` と `approve_retry` の2つの手動解決アクションを提供する。

### Tactics

- 既存Issueへの手動紐付け時は、GitHub Issue URLがProject repositoryとissue numberに一致することを検証する。
- controlled retry時はIssue Draftを `approved` に戻し、Review blockerを解決する。
- 手動解決には `resolution_note` を必須化する。
- `retry_approved` attempt statusを追加する。
- publish成功レスポンスとAuditLogへ `attempt_id` を追加する。
- OpenAPIと生成型を同期する。

### Assessment

service specとrequest specで、手動紐付け、controlled retry、不正repository URL、resolution note必須、pendingなしを確認した。全RSpec、Zeitwerk、OpenAPI verify、frontend build、E2E、npm auditも成功。

### Conclusion

Issue #4のreconciliation実装は、方針、attempt監査、marker検索、API実行、手動解決まで揃った。残るクローズ条件は実GitHub App credentialでのconnect + publish + reconcile smokeと、必要に応じたFrontend管理導線である。

### Knowledge

controlled retryは自動再作成ではなく、人間が「GitHub Issueが存在しない」と確認した後にIssue Draftを `approved` へ戻す。これにより二重Issue作成リスクを下げる。

## 良かった点

- 0件/複数件Review blockerに安全な出口を追加した。
- 手動紐付けではGitHub URLのrepository/issue numberを検証して誤紐付けを抑制した。
- controlled retryはattemptを `retry_approved` として監査できる。
- `resolution_note` 必須により、レビュー判断の根拠をAuditLog/Reviewに残せる。
- publish成功AuditLogにも `attempt_id` が入るようになった。
- OpenAPIとfrontend生成型まで同期した。

## 改善点

- 実GitHub App credentialでのlive smokeは未実施。
- Frontendから手動解決APIを操作する管理導線は未実装。
- GitHub Enterpriseやcustom domainには未対応で、URL検証は `github.com` 前提である。
- actor_idがまだsystem固定で、誰が手動解決したかを実ユーザーとして追跡できない。
- controlled retryの回数制限やcooldownは未実装。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | 実GitHub App credentialでconnect + publish + reconcile smoke | Issue #4クローズ判定に必須 |
| P1 | Frontend管理導線を追加 | 運用UXに必須 |
| P1 | actor_idを実ユーザーへ接続 | 監査性改善 |
| P1 | controlled retry回数制限/cooldown | 二重Issueリスク低減 |
| P2 | GitHub Enterprise URL対応 | 将来拡張 |

## STRIDE / ISO25010確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | GitHub URLのrepositoryとissue numberを検証 | 将来はGitHub APIでIssue実在確認 |
| Tampering | resolution_note必須で判断根拠を残す | actor_idと署名付き承認を追加 |
| Repudiation | AuditLog/Review/attemptに手動解決を保存 | 実ユーザー認証導入後にactorを保存 |
| Information Disclosure | token/raw responseは保存しない | resolution_noteのsecret scanを追加 |
| Reliability | controlled retryとmanual linkの出口を実装 | retry回数制限とcooldownを追加 |
| Maintainability | service分離とrequest specを追加 | controller orchestrationを将来service化 |

## 次アクション

1. 実GitHub App credentialでconnect + publish + reconcile smokeを実施する。
2. Frontend管理導線を追加する。
3. GitHub search retry/backoff方針をADR化する。
4. actor_idを実ユーザーへ接続する。
5. controlled retry回数制限/cooldownを設計する。

## 検証結果

- `bundle exec rspec spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/services/issue_draft_publish_gate_spec.rb`: 26 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/services/issue_draft_publish_gate_spec.rb`: 32 examples, 0 failures
- `bundle exec rspec`: 122 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
