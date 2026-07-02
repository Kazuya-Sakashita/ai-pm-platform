# GitHub Search Retry Backoff ADR Review

## 評価日時

2026-07-02 19:10:51 JST

## 評価担当

- Codex
- CTO
- Tech Lead
- Backend Architect
- Security Engineer
- QA
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- ADR
- STRIDE
- ISO25010
- DORA Metrics

## 対象

- Issue番号: #4
- 対象ファイル:
  - `docs/decisions/ADR-0008_github_search_retry_backoff.md`
  - `backend/app/services/github_issue_publish/reconciliation_service.rb`
  - `backend/spec/services/github_issue_publish/reconciliation_service_spec.rb`
  - `docs/decisions/ADR-0007_github_reconciliation_candidate_ranking.md`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- GitHub公式仕様を踏まえ、Search APIのrate limit、secondary rate limit、indexing delay、`incomplete_results` をADRとして整理した。
- `incomplete_results=true` では候補が1件でも自動reconcileしない方針を明文化した。
- ADRだけで終わらせず、ReconciliationServiceを安全側へ変更した。
- 不完全検索時のsafe error codeを `github_publish_reconciliation_incomplete_results` として分離した。
- Review blockerのnext actionに、cooldown後の再検索、候補確認、controlled retry禁止条件を残すようにした。
- RSpecで不完全検索時の自動紐付け禁止、Review blocker、AuditLog metadataを検証した。

## 改善点

- GitHub response headerの `retry-after`、`x-ratelimit-remaining`、`x-ratelimit-reset` はまだProviderErrorや監査metadataへ反映していない。
- retry count、next retry at、cooldown状態を保存する非同期reconciler jobは未実装。
- Frontendでは検索未完了表示はあるが、再検索可能時刻やrate limit理由はまだ表示できない。
- controlled retryのcooldown、retry count、承認者表示、理由テンプレートは未実装。
- live GitHub App credentialでrate limitではない通常search smokeは未実施。

## 優先順位

- P0: live GitHub App credentialでconnect/publish/reconcile/search metadataをsmoke testする。
- P1: GitHub response header parsingを追加し、safe retry metadataを保存する。
- P1: 非同期reconciler jobでretry count、next retry at、cooldownを管理する。
- P1: controlled retryにcooldown、承認者、理由テンプレートを追加する。
- P2: Frontendに再検索可能時刻とrate limit理由を表示する。

## 次アクション

- GitHub response header parsingとsafe metadata保存を実装する。
- ADR-0008に基づく非同期reconciler jobをIssue化またはIssue #4内で実装する。
- controlled retryのcooldown、retry count、承認者表示、理由テンプレートを追加する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

設計・実装改善として合格。`incomplete_results=true` を自動reconcileに使わない判断は、二重Issue作成と誤リンクを避けるうえで妥当である。ただし世界レベルのSaaS基準では、rate limit header parsing、非同期retry job、cooldown UI、controlled retry統制、live smokeが残るためIssue #4はまだクローズ不可。

## 検証結果

- 初回 `bundle exec rspec spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: sandbox DB接続制限で未実行
- 権限付き再実行 `bundle exec rspec spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 26 examples, 0 failures
- `git diff --check`: success
