# ISSUE-054 Review状態遷移の厳密監査 実装レビュー

## 評価日時

2026-07-07 08:08 JST

## 評価担当

Codex（Review Orchestrator / Security Engineer / QA / Backend Architect / Frontend Architect）

## 使用フレームワーク

- G-STACK
- DDD
- STRIDE
- OWASP Top 10
- ISO25010
- WCAG

## Issue番号

ISSUE-054 / GitHub #73

## 対象

- `docs/api/openapi.yaml`
- `backend/db/migrate/20260707075800_create_review_state_events.rb`
- `backend/db/migrate/20260707075900_backfill_review_state_events.rb`
- `backend/app/models/review_state_event.rb`
- `backend/app/services/review_transition_service.rb`
- `backend/app/controllers/api/v1/reviews_controller.rb`
- `backend/app/services/requirement_history_query.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- `review_state_events` を追加し、Review状態遷移のsource of truthを現在状態の `reviews` から分離した。
- `ReviewTransitionService` にReview作成、対応要求、解決、リスク受容、再オープンを集約し、状態更新とイベント作成を同一transactionにした。
- `accept_risk.approved_by` をクライアント入力ではなく認証済みactorから設定するようにした。
- ユーザー入力のReview本文、解決メモ、リスク受容理由、残存リスクに `SensitiveContentScanner` を適用し、secret/PII検知時は422で保存しない。
- `GET /reviews/{review_id}/events` と `POST /reviews/{review_id}/reopen` をOpenAPIへ追加し、Requirement履歴も `review_state_events` を読むようにした。
- 既存Reviewのbackfillで `legacy_backfill` と `actor_unknown` を残し、過去データの不確実性を隠さない設計にした。

## 改善点

- `ReviewTransitionService` は今回必要な状態遷移を明示メソッドで実装しているが、状態種類が増える場合は小さなPolicy Objectへの分離を検討する。
- ReviewEvent一覧はページングmetaを返すが、DB query自体は現状全件取得であり、大量イベント時のlimit/offsetは未実装。
- FrontendはRequirement履歴にイベント理由とIssue番号を表示するが、Review詳細画面でのイベント一覧UIは未実装。

## 改善案

- `ReviewStateTransitionPolicy` を追加し、状態遷移の許可条件をServiceから分離する。
- `GET /reviews/{review_id}/events` にpage/per_pageを適用する。
- Review Center側へ状態遷移イベント一覧を表示する。

## 優先順位

- P0: actor spoofing防止、secret/PII非保存、状態遷移イベント保存。対応済み。
- P1: Requirement履歴APIへのReviewEvent統合。対応済み。
- P2: ReviewEvent一覧のページングとReview Center表示。後続改善候補。

## 次アクション

1. PRを作成し、GitHub Actionsのverifyを確認する。
2. CI通過後にGitHub Issue #73をクローズする。
3. 後続候補としてReviewEvent一覧ページングとReview Center表示をIssue化するか判断する。
4. 次の親Issue #3残課題は ISSUE-052 または ISSUE-053 を優先する。

## 検証

- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH RAILS_ENV=test bundle exec rails db:migrate`: 成功。
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec`: 307 examples, 0 failures。
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good。
- `npm run api:verify`: 成功。Redocly CLIのNode version警告のみ。
- `npm run display:check`: 成功。
- `npm run frontend:build`: 成功。
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed。

## 判定

条件付き合格。ISSUE-054のMVPとして、Review状態遷移の厳密監査、actor spoofing防止、secret/PII保存防止、Requirement履歴への統合は完了水準に達した。ただし、世界レベルSaaSとしてはManual reconciliation actorの厳密化、ReviewEventページング、Review Center表示を次の改善対象とする。
