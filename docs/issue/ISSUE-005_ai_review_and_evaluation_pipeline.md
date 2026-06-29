# ISSUE-005: 専門家AIレビューと評価保存パイプラインを作る

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/5

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

このプロダクトの価値は、AIが作るだけでなく評価、改善、統制まで行う点にある。レビューなしで次工程へ進まない仕組みが必要である。

## 目的

専門家ロール別レビューを生成し、使用フレームワーク、良かった点、改善点、優先順位、次アクション、Issue番号を保存する。

## 完了条件

- レビューを作成できる
- レビュー対象とIssueを紐づけられる
- 使用フレームワークを保存できる
- 改善点と次アクションを必須にできる
- レビュー未実施フェーズを検出できる

## スコープ

- Codex一次レビュー
- レビューテンプレート
- 専門家ロール
- 評価フレームワーク選択
- レビュー保存

## 非スコープ

- 初期MVPでの外部AI自動実行
- 法務レビュー自動化

## 関連レビュー

- `docs/review/20260629_winning_strategy_review.md`
- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260629_roadmap_review.md`
- `docs/review/20260630_screen_design_review.md`
- `docs/review/20260630_api_design_review.md`
- `docs/review/20260630_db_design_review.md`

## レビュー結果

プロダクトの中核でありP0。ただし、レビューが形式化すると価値を失うため、必ず改善Issueへ接続する必要がある。

## 次アクション

- レビューデータモデル初稿は `docs/architecture/20260630_db_design.md` に作成済み
- レビュー未実施ゲートの初期状態は `docs/product/20260630_mvp_screen_design.md` に作成済み
- 複数AIレビュー比較のデータ構造を検討する
- ISSUE-007としてReview blocker UXを詳細化する
