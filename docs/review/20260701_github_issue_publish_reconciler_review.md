# 2026-07-01 GitHub Issue Publish Reconciler実装レビュー

## 評価日時

2026-07-01 12:16 JST

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

- `backend/app/services/github_issue_publish/marker_search_client.rb`
- `backend/app/services/github_issue_publish/reconciliation_service.rb`
- `backend/app/services/issue_draft_publish_gate.rb`
- `backend/app/models/github_issue_publish_attempt.rb`
- `backend/spec/services/github_issue_publish/marker_search_client_spec.rb`
- `backend/spec/services/github_issue_publish/reconciliation_service_spec.rb`
- `backend/spec/services/issue_draft_publish_gate_spec.rb`

## G-STACK

### Goal

GitHub Issue作成後の曖昧失敗をmarker検索で復旧し、二重Issue作成を防ぐ。

### Strategy

ADR-0006に沿って、GitHub Issue本文markerを検索し、1件のみならローカル台帳へ自動reconcile、0件/複数件ならReview blockerで人間レビューへ止める。

### Tactics

- GitHub App installation tokenで `/search/issues` を呼び、AI PM markerを検索する。
- `GithubIssuePublish::ReconciliationService` を追加し、exact matchを `published` / `reconciled` に更新する。
- 0件/複数件は `GitHub Publish Reconciler` の `action_required` Reviewを作成する。
- GitHub reconciliation blockerが残る場合はpublish gateで再publishを止める。
- reconciliation結果をAuditLogへ保存する。

### Assessment

marker検索client、reconciliation service、publish gateのRSpecを追加し、1件/0件/複数件/provider errorを確認した。全RSpec、Zeitwerk、OpenAPI verify、frontend build、E2E、npm auditも成功。

### Conclusion

ADR-0006のreconciliation中核は実装済みになった。ただしreconcilerのjob/API実行導線、Review blockerからの手動紐付け/controlled retry、実GitHub App credentialでのlive smokeは未完了のため、Issue #4はまだクローズ不可。

### Knowledge

GitHub searchはindexing delayやrate limitを持つため、運用では短いretry/backoffと人間レビュー導線が必要。今回の実装は自動再作成を避ける安全側に寄せた。

## 良かった点

- marker検索により二重Issue作成前の照合経路ができた。
- 1件一致時にIssue Draftとattemptを自動で `published` / `reconciled` へ更新できる。
- 0件/複数件時はReview blockerで止まり、勝手にIssueを選ばない。
- publish gateがGitHub reconciliation blockerを検知するようになった。
- GitHub tokenやraw responseを保存せず、safe errorと監査metadataに限定した。
- AuditLogでreconciled/blockedの判断を追跡できる。

## 改善点

- Reconciler serviceを起動するjob/API/管理画面導線が未実装。
- Review blockerから手動で正しいIssueを選ぶUI/APIが未実装。
- GitHub searchのindexing delay、rate limit、retry/backoff方針が未実装。
- 実GitHub App credentialでのconnect + publish + reconcile smokeは未実施。
- `issue_draft.github_published` のAuditLogにはまだattempt_idが入っていない。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | Reconciler実行job/APIを追加 | 障害復旧導線に必須 |
| P0 | Review blockerから手動紐付け/controlled retryを追加 | 0件/複数件の出口に必須 |
| P0 | 実GitHub App credentialでconnect + publish + reconcile smoke | Issue #4クローズ判定に必須 |
| P1 | GitHub search retry/backoff設計 | 運用品質改善 |
| P1 | publish成功AuditLogへattempt_id追加 | 監査性改善 |

## STRIDE / ISO25010確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | repositoryとinstallation accountを照合して検索する | live smokeで権限境界を確認 |
| Tampering | 複数一致時に自動選択しない | 手動紐付け時にも監査ログ必須 |
| Repudiation | reconciled/blockedをAuditLogへ記録 | publish成功AuditLogにもattempt_idを追加 |
| Information Disclosure | token/raw responseを保存しない | Review blockerにもsafe情報のみ保存 |
| Reliability | exact match復旧とreview stopを実装 | retry/backoffとjob化が必要 |
| Maintainability | service/client/specを分離 | GitHub App token生成の重複を将来共通化 |

## 次アクション

1. Reconciler実行job/APIを追加する。
2. Review blockerから手動紐付け/controlled retryを実装する。
3. 実GitHub App credentialでconnect + publish + reconcile smokeを行う。
4. GitHub search retry/backoff方針をADR化する。
5. `issue_draft.github_published` AuditLogへattempt_idを追加する。

## 検証結果

- `bundle exec rspec spec/services/issue_draft_publish_gate_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 26 examples, 0 failures
- `bundle exec rspec`: 110 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
