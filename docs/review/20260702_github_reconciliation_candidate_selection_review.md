# GitHub Reconciliation Candidate Selection Review

## 評価日時

2026-07-02 05:02:38 JST

## 評価担当

- Codex
- Tech Lead
- Backend Architect
- Frontend Architect
- QA
- Security Engineer

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- WCAG

## 対象

- Issue番号: #4
- 対象ファイル:
  - `docs/api/openapi.yaml`
  - `backend/app/controllers/api/v1/issue_drafts_controller.rb`
  - `backend/spec/requests/api/v1/issue_drafts_spec.rb`
  - `frontend/app/workspace-client.tsx`
  - `frontend/app/globals.css`
  - `frontend/e2e/meeting-workspace.spec.ts`
  - `frontend/lib/api/schema.d.ts`

## 良かった点

- marker検索で複数候補が見つかった場合に、APIから安全な候補情報を返せるようにした。
- 候補レスポンスはIssue番号、URL、repository、GitHub API ID、node IDに限定し、idempotency digestや内部例外を露出しない。
- Frontendで候補Issue一覧を表示し、選択した候補を手動リンクフォームへ反映できるようにした。
- 候補選択時にresolution noteの初期値を入れ、手動判断の監査ログを残しやすくした。
- Playwrightでmarker検索、候補一覧、候補選択、手動リンク成功までの導線を確認した。
- Request specで複数候補時のAPI contractを固定した。

## 改善点

- 候補Issueのタイトル、状態、作成日時、最終更新日時はまだ表示していない。
- 候補選択は手動フォームへの反映に留まり、候補から直接確定する専用APIはない。
- 候補が多い場合のページング、並び順、優先度スコアは未設計。
- 候補一覧のキーボード操作と選択済み状態のaria表現は最小限で、アクセシビリティ改善余地がある。
- 実GitHub App credentialでのmarker検索候補表示smokeは未実施。

## 優先順位

- P0: 実GitHub App credentialでmarker検索候補表示と手動リンクsmokeを実施する。
- P1: 候補にtitle/state/updated_atを追加し、ユーザーが選びやすい情報量へ改善する。
- P1: 選択済み候補の視覚状態とaria属性を追加する。
- P1: 候補が多い場合の上限、並び順、スコアリング方針をADR化する。
- P2: 候補から直接manual reconciliationする専用操作を検討する。

## 次アクション

- marker検索候補の表示情報を拡張するAPI設計を検討する。
- Candidate selection UIのアクセシビリティを改善する。
- live GitHub App credentialが設定できる環境でsmoke testを実施する。
- GitHub search retry/backoff、indexing delay、rate limit方針をADR化する。

## Issue番号

- #4

## レビュー結果

実装・API設計・テスト工程として合格。これまで手入力に寄っていた手動reconciliationが、marker検索候補を見て選択できる導線へ進化した。ただし世界レベルのSaaS基準では、候補の判断材料、選択済み状態、live smoke、GitHub searchの遅延/レート制御が不足しているため、Issue #4はまだクローズ不可。

## 検証結果

- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `bundle exec rspec spec/requests/api/v1/issue_drafts_spec.rb`: 19 examples, 0 failures
- `npm run frontend:e2e`: 11 passed
- `bundle exec rspec`: 124 examples, 0 failures
- `git diff --check`: success
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm audit --omit=dev`: 0 vulnerabilities
