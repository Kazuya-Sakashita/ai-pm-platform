# 2026-07-01 GitHub Reconciliation API実装レビュー

## 評価日時

2026-07-01 12:26 JST

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

- `docs/api/openapi.yaml`
- `frontend/lib/api/schema.d.ts`
- `backend/config/routes.rb`
- `backend/app/controllers/api/v1/issue_drafts_controller.rb`
- `backend/app/models/job.rb`
- `backend/spec/requests/api/v1/issue_drafts_spec.rb`

## G-STACK

### Goal

GitHub Issue publish reconciliationをAPIから実行できるようにし、運用時の復旧導線を作る。

### Strategy

`POST /issue-drafts/{issue_draft_id}/reconcile-github-publish` を追加し、最新の `reconciliation_required` attemptを対象にreconcilerを実行する。処理結果はJob、AuditLog、Review blockerへ接続する。

### Tactics

- OpenAPIへreconcile endpointとresponse schemaを追加する。
- `github_reconciliation` job typeを追加する。
- controllerでpending attemptを検索し、ReconciliationServiceを呼び出す。
- exact matchは `reconciled`、0件/複数件は `review_required` として返す。
- provider error時はjob failedとAuditLogを残す。

### Assessment

request specでreconciled、review_required、pendingなし、provider errorを検証した。全RSpec、Zeitwerk、OpenAPI verify、frontend build、E2E、npm auditも成功。

### Conclusion

reconcilerのAPI実行導線は実装済み。Issue #4の残P0は、Review blockerからの手動紐付け/controlled retryと実GitHub App credentialでのconnect + publish + reconcile smoke。

### Knowledge

今回のAPIは同期実行でJobを記録するMVP実装である。GitHub searchのindexing delayやrate limitに備えるには、次に非同期job化、retry/backoff、手動紐付けUI/APIが必要。

## 良かった点

- OpenAPI、Backend、生成型を同時に更新した。
- reconciliation APIがJobとAuditLogに接続された。
- 0件/複数件時のReview blocker結果をAPI responseで返せる。
- pending attemptがない場合は409で安全に停止する。
- provider error時にsafe errorとattempt_idを返し、raw responseやtokenを出さない。

## 改善点

- 手動紐付け/controlled retry APIは未実装。
- GitHub searchのretry/backoffは未実装。
- APIは同期実行であり、長いGitHub応答やrate limitに弱い。
- live GitHub App credentialでのE2E smokeは未実施。
- Frontendからreconciliation APIを起動する管理導線は未実装。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | 手動紐付け/controlled retry APIを追加 | 0件/複数件の出口に必須 |
| P0 | 実GitHub App credentialでconnect + publish + reconcile smoke | Issue #4クローズ判定に必須 |
| P1 | GitHub search retry/backoff ADR | 運用品質改善 |
| P1 | 非同期job worker化 | レスポンス時間とrate limit対応 |
| P1 | Frontend管理導線 | 実運用UX改善 |

## STRIDE / ISO25010確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | issue_draft配下のpending attemptのみ対象 | 将来はproject権限/actor_idを明示 |
| Tampering | APIは自動選択を1件一致だけに制限 | 手動紐付け時も二重監査を必須化 |
| Repudiation | Job/AuditLogに成功/失敗を残す | actor_idを実ユーザーに接続 |
| Information Disclosure | safe errorのみ返す | GitHub raw responseは保存しない方針を維持 |
| Reliability | pendingなし/ambiguous/provider errorを分岐 | retry/backoffと非同期化が必要 |
| Maintainability | OpenAPIとrequest specを同期 | controller肥大化前にservice orchestrationへ分離 |

## 次アクション

1. 手動紐付け/controlled retry APIを実装する。
2. 実GitHub App credentialでconnect + publish + reconcile smokeを行う。
3. GitHub search retry/backoff方針をADR化する。
4. reconciliation APIのFrontend管理導線を追加する。
5. `issue_draft.github_published` AuditLogへattempt_idを追加する。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/issue_draft_publish_gate_spec.rb`: 24 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec`: 114 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

- ISSUE-004
- GitHub Issue #4
