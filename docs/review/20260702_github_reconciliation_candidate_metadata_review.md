# GitHub Reconciliation Candidate Metadata Review

## 評価日時

2026-07-02 06:43:28 JST

## 評価担当

- Codex
- Product Manager
- Tech Lead
- Backend Architect
- Frontend Architect
- QA
- Security Engineer
- UI/UX Designer

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- HEART
- WCAG

## 対象

- Issue番号: #4
- 対象ファイル:
  - `docs/api/openapi.yaml`
  - `backend/app/services/github_issue_publish/marker_search_client.rb`
  - `backend/app/controllers/api/v1/issue_drafts_controller.rb`
  - `backend/spec/services/github_issue_publish/marker_search_client_spec.rb`
  - `backend/spec/requests/api/v1/issue_drafts_spec.rb`
  - `frontend/app/workspace-client.tsx`
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `frontend/lib/api/schema.d.ts`

## 良かった点

- marker検索候補へtitle、state、updated_at、scoreを追加し、候補選択時の判断材料を増やした。
- GitHub search responseの必要項目だけをsafeな候補メタデータとしてAPI responseへ通した。
- Frontendで候補のタイトル、状態、更新日時、スコアを表示し、URLだけに依存しない選択ができるようにした。
- OpenAPIと生成型を更新し、Frontendが候補メタデータを型安全に扱えるようにした。
- MarkerSearchClient spec、request spec、Playwright E2EでBackendからUIまでのcontractを確認した。

## 改善点

- scoreの意味や並び順はまだ明示しておらず、候補の優先度ロジックは未設計。
- GitHub Issueの状態はopen/closedのみで、state_reasonやdraft/lockedなどの詳細は未表示。
- titleが長い場合の視覚回帰確認は未実施。
- 候補選択済み状態の視覚表現とaria属性は未実装。
- 実GitHub App credentialでの候補メタデータ表示smokeは未実施。

## 優先順位

- P0: 実GitHub App credentialで候補メタデータ表示をsmoke testする。
- P1: 候補の並び順、score解釈、最大表示件数をADR化する。
- P1: 選択済み候補の視覚状態とaria属性を追加する。
- P1: 長いtitle/URLの狭幅表示をPlaywright screenshotで確認する。
- P2: state_reason、labels、authorなどの追加表示要否を検討する。

## 次アクション

- GitHub search候補の並び順、score、indexing delay、rate limit方針をADR化する。
- Candidate selection UIに選択済み状態とアクセシビリティ属性を追加する。
- long title/URLの視覚回帰E2Eを追加する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。

## Issue番号

- #4

## レビュー結果

実装・API設計・UX改善として合格。候補選択UIはURL羅列から、タイトル、状態、更新日時、スコアを比較できる状態へ進んだ。ただし世界レベルのSaaS基準では、候補ランキングの根拠、選択済み状態、長文時の視覚品質、live smokeが不足しているためIssue #4はまだクローズ不可。

## 検証結果

- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 11 passed
- `bundle exec rspec spec/services/github_issue_publish/marker_search_client_spec.rb spec/requests/api/v1/issue_drafts_spec.rb`: 21 examples, 0 failures
