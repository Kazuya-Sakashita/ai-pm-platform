# GitHub Reconciliation Cooldown Retry Review

## 評価日時

2026-07-02 20:11:28 JST

## 評価担当

- Codex
- CTO
- Tech Lead
- Backend Architect
- Frontend Architect
- Security Engineer
- QA
- DevOps
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- ADR
- STRIDE
- ISO25010
- DORA Metrics
- HEART

## 対象

- Issue番号: #4
- 対象ファイル:
  - `backend/db/migrate/20260702120500_add_reconciliation_retry_metadata_to_github_issue_publish_attempts.rb`
  - `backend/app/models/github_issue_publish_attempt.rb`
  - `backend/app/models/issue_draft.rb`
  - `backend/app/services/github_issue_publish/reconciliation_service.rb`
  - `backend/app/services/github_issue_publish/manual_reconciliation_service.rb`
  - `backend/app/controllers/api/v1/issue_drafts_controller.rb`
  - `docs/api/openapi.yaml`
  - `frontend/app/workspace-client.tsx`
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `docs/decisions/ADR-0008_github_search_retry_backoff.md`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- `github_issue_publish_attempts` に `reconciliation_retry_count` と `next_reconciliation_retry_at` を追加し、retry/cooldown状態を監査できるようにした。
- 0件、不完全検索、rate limit時に次回再検索時刻を設定できるようにした。
- cooldown中はmarker search APIを409で停止し、無駄なJobを作らないようにした。
- controlled retry承認もcooldown中は409で停止し、二重Issue作成リスクを下げた。
- pending reconciliation summaryとreconcile API responseにretry count、next retry at、cooldown状態を追加した。
- Frontendで再検索回数と次回再検索時刻を表示し、cooldown中はマーカー検索と再試行承認をdisabledにした。
- Playwright E2Eでcooldown表示、危険操作disabled、既存Issue手動リンクは継続可能であることを検証した。

## 改善点

- ActiveJob等による本格的な非同期reconciler jobは未実装。
- cooldown後に自動でmarker searchを再実行するschedulerは未実装。
- retry履歴はattempt上のcountのみで、各retry attemptの詳細履歴テーブルは未実装。
- controlled retryの承認者表示と理由テンプレートは未実装。
- live GitHub App credentialでのconnect/publish/reconcile smokeは未実施。
- Job modelにはsafe metadata columnがなく、retry metadataはattempt/API/AuditLog中心である。

## 優先順位

- P0: live GitHub App credentialでconnect/publish/reconcile smokeを実施する。
- P1: ActiveJob等でcooldown後のreconciler retry jobを実装する。
- P1: controlled retryの承認者表示、理由テンプレート、最終確認UIを追加する。
- P1: Job safe metadata方針をADR化し、Job一覧からretry metadataを参照できるようにするか判断する。
- P2: retry履歴の詳細監査テーブルを検討する。
- P2: スクリーンリーダー確認を手動QA checklistに追加する。

## 次アクション

- ADR-0008に基づき、ActiveJob等の非同期reconciler jobを実装する。
- controlled retryの承認者表示と理由テンプレートを追加する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。
- Job safe metadataの保存方針をADR化する。

## Issue番号

- #4

## レビュー結果

実装・UX・安全性改善として合格。retry count、next retry at、cooldown UIにより、GitHub Searchのindexing delayやrate limit直後に再検索やcontrolled retryを連打するリスクを下げられた。ただし世界レベルのSaaS基準では、cooldown状態を表示するだけでは不十分であり、本格的な非同期retry job、承認者表示、理由テンプレート、live smoke、詳細retry履歴が残るためIssue #4はまだクローズ不可。

## 検証結果

- `bundle exec rails db:migrate`: success
- `RAILS_ENV=test bundle exec rails db:migrate`: success
- `bundle exec rspec spec/models/github_issue_publish_attempt_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/manual_reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 39 examples, 0 failures
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 14 passed
- `git diff --check`: success
