# 2026-07-01 GitHub Issue Publish Reconciliation ADRレビュー

## 評価日時

2026-07-01 11:41 JST

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
- ADR
- DDD

## 対象Issue

- ISSUE-004
- GitHub: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4

## 対象成果物

- `docs/decisions/ADR-0006_github_issue_publish_reconciliation.md`
- `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## G-STACK

### Goal

GitHub Issue作成成功後にDB保存が失敗した場合でも、二重Issue作成を避けて復旧できる方針を決める。

### Strategy

GitHub Issue本文にAI PM markerを埋め込み、曖昧な失敗では即retryせずreconciliationに回す。1件だけ特定できた場合に自動紐付けし、0件/複数件は人間レビューへ止める。

### Tactics

- `issue_draft_id` と `idempotency_digest` をGitHub Issue本文markerに入れる。
- Idempotency-Keyの生値は保存しない。
- publish attempt tableを将来追加する。
- ambiguous failureを分類し、GitHub側をmarker検索して復旧する。
- 一意に特定できない場合はReview blockerを作る。

### Assessment

ADRとして、二重Issue作成を避ける判断基準、保存する情報、保存しない情報、future data model、failure classificationを定義できた。ただし実装は未着手であり、現時点では運用リスクを完全には解消していない。

### Conclusion

設計判断としては妥当。次は `github_issue_publish_attempts` とreconciler実装へ進むべき。ADR追加だけではIssue #4はクローズ不可。

### Knowledge

GitHub Issue作成は外部side effectであり、DB transactionだけでは完全に保護できない。source of truthをGitHubだけにもDBだけにも寄せず、markerとreconciliationで整合性を回復する。

## 良かった点

- 二重Issue作成を防ぐ明確な判断基準を作った。
- Idempotency-Key生値を外部Issue本文やDBに出さない方針を維持した。
- GitHub 4xx、permission error、timeout、DB保存失敗を分類した。
- 0件/複数件を自動判断しない方針にした。
- 将来テーブルと実装follow-upが具体化された。

## 改善点

- ADRのみで実装はまだない。
- GitHub searchのindexing delayやrate limitへの具体的なretry/backoff設計は未確定。
- marker削除時の復旧手段が弱い。
- `publish_reconciliation_required` statusやReview blockerの実装は未定義。
- live GitHub App credentialでのconnect + publish smokeは未実施。

## 優先順位

| Priority | 内容 | 判断 |
| --- | --- | --- |
| P0 | `github_issue_publish_attempts` を実装 | Reconciliationの前提 |
| P0 | ambiguous failure分類とreconciler serviceを実装 | 二重Issue防止に必須 |
| P0 | 実GitHub App credentialでconnect + publish smokeを実施 | Issue #4クローズ判定に必須 |
| P1 | marker検索のrate limit/backoff設計 | 運用品質に必要 |
| P1 | 0件/複数件時のReview blocker実装 | 人間レビュー導線に必要 |
| P2 | marker削除時の手動link UI/API | 運用補助 |

## STRIDE / ISO25010確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | markerだけでは所有証明ではない | GitHub installation/repository照合と併用 |
| Tampering | markerを手動削除されると検索できない | node_id保存と手動link APIを追加 |
| Repudiation | attempt tableで監査性が上がる | AuditLogにもattempt idを保存 |
| Information Disclosure | idempotency生値を保存しない | digest長と公開範囲を固定 |
| Reliability | 曖昧な失敗に強くなる | reconciler実装とretry policyが必要 |
| Maintainability | failure分類が明確 | service境界を実装時に守る |

## 次アクション

1. `github_issue_publish_attempts` migration/model/specを追加する。
2. `GithubIssuePublishService` にattempt記録を接続する。
3. ambiguous failure用の `publish_reconciliation_required` または同等statusを実装する。
4. GitHub marker検索reconcilerを実装する。
5. 0件/複数件時にReview blockerを作る。
6. 実GitHub App credentialでconnect + publish smokeを行う。

## 検証結果

- ドキュメント追加のみ。
- `git diff --check`: success
- 実装テストは未実施。次の実装フェーズでRSpec/CIを実施する。

## Issue番号

- ISSUE-004
- GitHub Issue #4
