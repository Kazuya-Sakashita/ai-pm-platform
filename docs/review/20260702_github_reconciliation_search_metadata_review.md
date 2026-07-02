# GitHub Reconciliation Search Metadata Review

## 評価日時

2026-07-02 18:42:21 JST

## 評価担当

- Codex
- Product Manager
- Tech Lead
- Backend Architect
- Frontend Architect
- QA
- Security Engineer
- UI/UX Designer

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- HEART
- WCAG

## 対象

- Issue番号: #4
- 対象ファイル:
  - `docs/api/openapi.yaml`
  - `backend/app/services/github_issue_publish/marker_search_client.rb`
  - `backend/app/services/github_issue_publish/reconciliation_service.rb`
  - `backend/app/controllers/api/v1/issue_drafts_controller.rb`
  - `frontend/app/workspace-client.tsx`
  - `frontend/app/globals.css`
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `frontend/lib/api/schema.d.ts`
  - `docs/issue/ISSUE-004_github_issue_and_openapi_pipeline.md`

## 良かった点

- GitHub Search APIの `total_count` と `incomplete_results` をreconciliation APIへ通し、候補表示の不確実性をUIに出せるようにした。
- `search_result_limit` と `search_has_more_results` を追加し、上位10件のみ表示されている状態を明示できるようにした。
- `MarkerSearchClient` に検索結果メタデータを持つ `SearchResult` を追加し、既存の候補配列ロジックを保ちながら拡張した。
- Reconciliation audit metadataにも検索総数、不完全結果、上限超過有無を残せるようにした。
- Frontend候補ヘッダーに検索総数、上位10件のみ表示、検索未完了を表示し、レビュアーが過信しにくい導線にした。
- Request spec、service spec、MarkerSearchClient spec、Playwright E2EでBackendからUIまでのcontractを確認した。

## 改善点

- GitHub Searchのindexing delay、rate limit、retry/backoff方針はまだADR化されていない。
- 10件候補が実際に並んだ場合の視覚密度、スクロール量、誤選択リスクは未検証。
- `incomplete_results=true` の場合に再検索を促す専用CTAは未実装。
- live GitHub App credentialでのsearch metadata smokeは未実施。
- GitHub Search API仕様変更に備えた監視やメトリクスは未設計。

## 優先順位

- P0: live GitHub App credentialでconnect/publish/reconcile/search metadataをsmoke testする。
- P1: GitHub Search retry/backoff、indexing delay、rate limit方針をADR化する。
- P1: 10件候補時のUI密度と操作性をE2Eまたは視覚確認で検証する。
- P1: controlled retryのcooldown、retry count、承認者表示、理由テンプレートを追加する。
- P2: `incomplete_results=true` 時の再検索CTAと監視指標を検討する。

## 次アクション

- GitHub Search retry/backoff方針をADR化する。
- 10件候補時のUI密度と操作性を検証する。
- controlled retryのcooldown、retry count、承認者表示、理由テンプレートを追加する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

実装・API設計・UX改善として合格。候補が上位10件に制限される場合やGitHub Searchが不完全な場合をUIと監査に出せるようになり、人間レビューの判断材料が増えた。ただし世界レベルのSaaS基準では、retry/backoff設計、10件候補の操作性、live smoke、controlled retry制御が残るためIssue #4はまだクローズ不可。

## 検証結果

- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 12 passed
- `bundle exec rspec spec/services/github_issue_publish/marker_search_client_spec.rb spec/services/github_issue_publish/reconciliation_service_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 25 examples, 0 failures
- `git diff --check`: success
