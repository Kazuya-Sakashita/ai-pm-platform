# ISSUE-001: プロジェクト基盤、市場調査、競合分析、開発統制を整備する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/1

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

AI議事録プラットフォームをAI PMへ発展させるには、実装より前に市場、競合、MVP、レビュー運用、Issue運用、ADR運用を定義する必要がある。

## 目的

プロジェクト全体の開発ルール、調査結果、レビュー保存ルール、初期Issue台帳を整備する。

## 完了条件

- `AGENTS.md` が作成されている
- `docs/` 配下の必要ディレクトリが作成されている
- 市場調査が保存されている
- 競合分析が保存されている
- 勝ち筋、MVP、要件定義、ロードマップが保存されている
- 各フェーズレビューが `docs/review/` に保存されている
- GitHub Issue登録が完了している、または登録待ち理由が明記されている

## スコープ

- Project Charter
- AGENTS
- docs構成
- 市場調査
- 競合分析
- MVP
- ロードマップ
- 初期レビュー

## 非スコープ

- アプリ実装
- UI実装
- API実装
- DB実装

## 関連レビュー

- `docs/review/20260629_market_research_review.md`
- `docs/review/20260629_competitive_analysis_review.md`
- `docs/review/20260629_winning_strategy_review.md`
- `docs/review/20260629_roadmap_review.md`

## レビュー結果

初期レビューでは、方向性は妥当だが定量調査、顧客インタビュー、価格検証が不足していると評価した。

## 次アクション

- GitHub認証復旧後にGitHub Issueとして登録する
- 競合比較の定量深掘りを追加する
- ユーザーインタビュー設計を作成する
