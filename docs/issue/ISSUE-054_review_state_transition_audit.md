# ISSUE-054: Review状態遷移の厳密監査を実装する

## Issue番号

ISSUE-054

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/73

登録日: 2026-07-07
状態: OPEN（実装完了、PR CI確認待ち）

## 背景

ISSUE-050でRequirement差分履歴とレビュー履歴タイムラインを実装したが、現行の `reviews` テーブルは現在状態のみを保持している。そのため、レビュー依頼、対応要求、解決、リスク受容、再オープンなどの状態遷移を厳密な監査イベントとして復元できない。

世界レベルのSaaSとしては、承認判断の根拠、Security/QAブロッカーの解除、リスク受容の期限管理を後から説明できる必要がある。

## 目的

Reviewの状態変更を監査可能なイベントとして保存し、Requirement履歴タイムラインや将来のRelease判定で、誰が、いつ、どの理由でレビュー状態を変更したかを追跡できるようにする。

## 完了条件

- Review作成、状態変更、解決、リスク受容、再オープンをイベントとして保存できる
- Review状態遷移イベントにactor、理由、発生日時、関連Issue番号を保存できる
- raw secret、不要PII、長文レビュー原文全文をイベントへ保存しない
- Requirement履歴APIがReview状態遷移イベントを表示できる
- OpenAPI、Backend、Frontend、RSpec、Playwrightが更新されている
- 設計レビュー、実装レビュー、テスト結果が `docs/review/` に保存されている

## スコープ

- Review状態遷移イベントの保存設計
- Review操作APIのイベント記録
- Requirement履歴APIへの統合
- Review状態遷移のRSpec
- Requirement Workspaceの履歴表示更新

## 非スコープ

- 外部AIレビュー結果の自動取り込み
- GitHub PRレビューとの同期
- 複数人同時編集のリアルタイム競合解決

## 関連レビュー

- `docs/review/20260707_requirement_history_timeline_design_review.md`
- `docs/review/20260707_requirement_history_timeline_implementation_review.md`
- `docs/review/20260707_review_state_transition_audit_design_review.md`
- `docs/review/20260707_review_state_transition_audit_implementation_review.md`

## レビュー結果

ISSUE-050のMVPではReview作成と現在状態をタイムラインに表示できるが、厳密な監査性には不足がある。Security EngineerとQAのP0 blockerをRelease判定に使うには、レビュー状態遷移そのものをイベントとして保存する必要がある。

## 優先度

P1

## 次アクション

1. PR CIとmain CIを確認する。
2. CI通過後にGitHub Issue #73をクローズする。
3. Manual reconciliation actor引き継ぎとReviewEventページングを後続Issue化するか判断する。
4. 次はISSUE-052またはISSUE-053を優先する。

## 実装メモ

2026-07-07 08:08 JST追加:

- `review_state_events` テーブルと `ReviewStateEvent` modelを追加した。
- 既存Reviewを `legacy_backfill` として状態遷移イベントへbackfillし、actor不明は `actor_unknown` として明示した。
- `ReviewTransitionService` を追加し、Review作成、対応要求、解決、リスク受容、再オープンを状態更新とイベント作成の同一transactionで処理するようにした。
- `accept_risk.approved_by` はクライアント入力ではなく認証済みactor IDをサーバー側で設定するようにした。
- ユーザー入力のReview本文、解決メモ、リスク受容理由、残存リスクは `SensitiveContentScanner` で検査し、secret/PII検知時は422で保存しないようにした。
- `GET /api/v1/reviews/{review_id}/events` と `POST /api/v1/reviews/{review_id}/reopen` を追加した。
- OpenAPI検証ゲートとGitHub publish reconciliation blockerを `ReviewTransitionService` 経由へ移した。
- Manual GitHub reconciliationではUI操作actorを `ReviewTransitionService` へ渡し、状態遷移イベントのactorに保存するようにした。
- `RequirementHistoryQuery` をReview現在状態推測から `ReviewStateEvent` 参照へ切り替えた。
- Requirement Workspaceの履歴タイムラインでReview状態遷移のactor、状態、理由要約、関連Issueを表示するようにした。

## 検証結果

- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH RAILS_ENV=test bundle exec rails db:migrate`
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec`: 307 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`
- `npm run display:check`
- `npm run frontend:build`
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed
