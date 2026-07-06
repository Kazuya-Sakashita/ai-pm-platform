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
- `docs/review/20260705_expert_subagent_governance_review.md`
- `docs/review/20260705_expert_subagent_pilot_issue_039_review.md`
- `docs/review/20260706_ai_review_pipeline_closure_review.md`

## レビュー結果

プロダクトの中核でありP0。ただし、レビューが形式化すると価値を失うため、必ず改善Issueへ接続する必要がある。

2026-07-06にクローズ判定レビューを実施した。Review model/API/OpenAPI contract、Review Center連動、OpenAPI validation/GitHub publish reconciliationのReview blocker、専門家サブエージェント運用文書、expert review schema、ISSUE-039パイロットにより、ISSUE-005のMVP完了条件を満たした。Agent別UI、外部AI比較、フェーズ横断の未レビュー検出ダッシュボードはP1/P2後続改善として分離する。

## 次アクション

- GitHub Issue #5へクローズコメントを投稿し、Issueをクローズする。
- CI成功後にClosed状態、クローズ日、クローズコメント、main CI証跡を追記する。
- Agent別レビュー表示、外部AI比較、フェーズ横断review gateは後続Issue候補として扱う。
