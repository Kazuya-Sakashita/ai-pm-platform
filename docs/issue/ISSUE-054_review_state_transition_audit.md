# ISSUE-054: Review状態遷移の厳密監査を実装する

## Issue番号

ISSUE-054

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/73

登録日: 2026-07-07
状態: OPEN

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

## レビュー結果

ISSUE-050のMVPではReview作成と現在状態をタイムラインに表示できるが、厳密な監査性には不足がある。Security EngineerとQAのP0 blockerをRelease判定に使うには、レビュー状態遷移そのものをイベントとして保存する必要がある。

## 優先度

P1

## 次アクション

1. Review状態遷移イベントのデータモデルを設計する。
2. OpenAPIへReview event APIまたは既存Review response拡張を追加する。
3. `ReviewsController` のcreate、resolve、accept riskへイベント記録を追加する。
4. Requirement履歴APIへReview eventを統合する。
5. RSpecとPlaywrightで監査タイムラインを検証する。
