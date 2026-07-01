# GitHub Reconciliation Attempt Summary Implementation Review

## 評価日時

2026-07-01 19:39:54 JST

## 評価担当

- Codex
- Product Manager
- Tech Lead
- Backend Architect
- Frontend Architect
- Security Engineer
- QA

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- WCAG

## 対象

- Issue番号: #4
- 対象ファイル:
  - `docs/api/openapi.yaml`
  - `frontend/lib/api/schema.d.ts`
  - `backend/app/models/issue_draft.rb`
  - `backend/spec/requests/api/v1/issue_drafts_spec.rb`
  - `frontend/app/workspace-client.tsx`
  - `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- `IssueDraft` responseに `github_reconciliation.pending` を追加し、reconciliation requiredかどうかをFrontendが正確に判断できるようにした。
- pending attemptがないGitHub未接続エラーでは、marker検索、手動リンク、controlled retryの操作を表示しないようにした。
- pending attemptがある場合はattempt id、status、safe error、GitHub Issue番号/URLをsummaryとして返せるようにした。
- idempotency digestや内部例外など、UIに不要な機密/内部情報は返さないようにした。
- Request specでpending falseとpending trueの両方を検証した。
- Playwright E2EでGitHub未接続時に復旧操作が出ないことを検証した。
- OpenAPI型を再生成し、Frontendが契約に沿って `github_reconciliation` を参照するようにした。

## 改善点

- pending true時のFrontend表示は型とbuildで検証済みだが、Playwrightでのmock E2Eは未追加。
- marker検索候補一覧はまだAPI responseに含まれていない。
- controlled retryのcooldown、retry count、承認者表示は未実装。
- 実GitHub App credentialでconnect、publish、reconcile、manual resolveのlive smokeは未実施。
- 認証/認可が未接続のため、reconciliation操作権限の分離はまだできていない。
- `safe_error_detail` の日本語表示、多言語化、エラー要約のアクセシビリティ改善は未実装。

## 優先順位

- P0: 実GitHub App credentialでlive smokeを実施する。
- P1: pending true時のFrontend mock E2Eを追加する。
- P1: marker検索候補一覧と手動選択UIを追加する。
- P1: controlled retryのcooldown、retry count、承認者表示を追加する。
- P2: エラー表示の日本語化、フォーカス管理、補助テキストを改善する。

## 次アクション

- GitHub App credentialを設定できる環境で connect + publish + reconcile + manual resolve を実行する。
- marker検索結果候補を保持/返却するAPI設計を追加する。
- pending trueのreconciliation UIをmock E2Eで検証する。
- retry/backoff/cooldown方針をADR化する。

## Issue番号

- #4

## レビュー結果

実装・テスト工程として合格。未接続エラーとreconciliation requiredをUIで区別できるようになり、誤操作リスクは下がった。ただし世界レベルのSaaS基準では、実GitHub App credential smoke、候補Issue選択、retry制御、認可分離が残るため、Issue #4はまだクローズ不可。

## 検証結果

- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 18 examples, 0 failures
- `bundle exec rspec`: 123 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
