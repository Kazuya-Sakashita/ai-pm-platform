# 2026-07-01 GitHub Issue Publish Attempts実装レビュー

## 評価日時

2026-07-01 11:55 JST

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

- `backend/db/migrate/20260701114500_create_github_issue_publish_attempts.rb`
- `backend/app/models/github_issue_publish_attempt.rb`
- `backend/app/services/github_issue_publish_service.rb`
- `backend/spec/models/github_issue_publish_attempt_spec.rb`
- `backend/spec/services/github_issue_publish_service_spec.rb`
- `backend/spec/requests/api/v1/issue_drafts_spec.rb`

## G-STACK

### Goal

GitHub Issue publishの外部side effectを監査し、reconciliation実装の前提となるpublish attemptを保存する。

### Strategy

ADR-0006に沿って、publish開始、GitHub作成成功、ローカル保存成功、provider失敗、reconciliation requiredを `github_issue_publish_attempts` へ記録する。

### Tactics

- `github_issue_publish_attempts` tableを追加する。
- `started`、`github_created`、`local_saved`、`failed`、`reconciliation_required`、`reconciled` statusを定義する。
- `GithubIssuePublishService` でattemptを作成し、lifecycleを更新する。
- Idempotency-Keyの生値を保存せず、SHA-256 digestを保存する。
- GitHub作成後のローカル保存失敗は `github_publish_reconciliation_required` として止める。

### Assessment

model spec、service spec、request specで主要lifecycleを確認した。全RSpec、Zeitwerk、OpenAPI verify、frontend build、E2E、npm auditも成功。

### Conclusion

Reconciliationの土台としては前進。ただしGitHub marker検索reconciler、0件/複数件時のReview blocker、live GitHub App smokeは未実装のため、Issue #4はまだクローズ不可。

### Knowledge

現在は `issue_drafts.publish_idempotency_key` にもdigestを保存する。カラム名は歴史的にkeyだが、生値は保存しない運用へ変更した。

## 良かった点

- publishの外部side effectをattemptとして監査できるようになった。
- GitHub作成後、ローカル保存に失敗した場合にreconciliation requiredで停止できる。
- GitHub作成後、attempt更新に失敗した場合もreconciliation requiredで停止できる。
- Provider失敗時もsafe error code/detailをattemptへ残せる。
- Idempotency-Key生値の保存をやめ、digest保存へ寄せた。
- 同じidempotency digestで失敗再試行しても、attempt履歴を複数残せる。
- Request specでAPI経由のattempt作成まで確認した。

## 改善点

- Reconciler service本体は未実装。
- GitHub marker検索、0件/複数件時のReview blockerは未実装。
- `issue_drafts.publish_idempotency_key` は名称と保存値がずれており、将来 `publish_idempotency_digest` へrenameした方が明確。
- DBが完全に落ちた場合、attempt自体の更新もできないため、運用監視とjob retry設計が必要。
- live GitHub App credentialでのconnect + publish smokeは未実施。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | GitHub marker検索reconcilerを実装 | Reconciliation完了に必須 |
| P0 | 0件/複数件時のReview blockerを作成 | 人間レビュー導線に必須 |
| P0 | 実GitHub App credentialでconnect + publish smoke | Issue #4クローズ判定に必須 |
| P1 | `publish_idempotency_key` をdigest名称へrename | 保守性改善 |
| P1 | DB障害時のjob retry/monitoring方針 | 信頼性改善 |

## STRIDE / ISO25010確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | attemptは内部DBに紐づく | GitHub marker検索時もinstallation/repository照合を必須化 |
| Tampering | raw idempotency keyを保存しない | attempt更新権限をservice内に閉じる |
| Repudiation | attempt lifecycleで監査性が向上 | AuditLogにもattempt_idを追加する |
| Information Disclosure | safe errorのみ保存 | GitHub raw responseを保存しない方針を維持 |
| Reliability | local save failureをreconciliation requiredで止められる | reconciler serviceとretry policyが必要 |
| Maintainability | lifecycleがmodel methodに分離された | status遷移の厳密化を追加 |

## 次アクション

1. GitHub marker検索reconciler serviceを実装する。
2. 0件/複数件時にReview blockerを作成する。
3. `issue_draft.github_published` AuditLogへattempt_idを追加する。
4. `publish_idempotency_key` のdigest名称renameをADRまたはmigrationで検討する。
5. 実GitHub App credentialでconnect + publish smokeを行う。

## 検証結果

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rails db:migrate:redo VERSION=20260701114500`: success
- `RAILS_ENV=test bundle exec rails db:migrate:redo VERSION=20260701114500`: success
- `bundle exec rspec spec/models/github_issue_publish_attempt_spec.rb spec/services/github_issue_publish_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 18 examples, 0 failures
- `bundle exec rspec`: 103 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
