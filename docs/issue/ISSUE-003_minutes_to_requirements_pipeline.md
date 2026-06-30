# ISSUE-003: 議事録から要件定義ドラフトを生成する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/3

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

AI議事録ツールとの差別化には、会議内容を実装可能な要件に変換する能力が必要である。

## 目的

議事録から背景、目的、ユーザーストーリー、受け入れ条件、非機能要件、未決事項を生成する。

## 完了条件

- 要件定義ドラフトを生成できる
- 曖昧な項目を未決事項として抽出できる
- 専門家レビューを保存できる
- 人間が編集できる
- Issue生成に使える構造になっている

## スコープ

- 要件定義生成
- 未決事項抽出
- 受け入れ条件生成
- レビュー保存

## 非スコープ

- 完全自動承認
- 複数プロジェクト横断優先度最適化

## 関連レビュー

- `docs/review/20260629_mvp_review.md`
- `docs/review/20260629_requirements_review.md`
- `docs/review/20260630_screen_design_review.md`
- `docs/review/20260630_db_design_review.md`
- `docs/review/20260630_requirements_generation_mvp_review.md`

## レビュー結果

本プロダクトの中核機能としてP0。ただし、AI出力品質の評価セットと人間編集UIがないと信頼されない。

2026-06-30 16:40 JST追加:

- `requirements` テーブル、Requirement model、factoryを追加
- `RequirementGenerationService` とdeterministic providerを追加
- `/minutes/{minutes_id}/generate-requirement` を実装
- `/requirements/{requirement_id}` の取得/更新を実装
- Minutesが `approved` になるまでRequirement生成を409 `review_required` でブロック
- FrontendにRequirement Workspace、生成、編集保存、Requirement review依頼導線を追加
- Playwright E2EでMinutes承認後のRequirement生成、編集保存、レビュー依頼を確認
- `bundle exec rspec`: 33 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI contract warningなし
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

未完了:

- Requirement承認APIとReview gate
- Requirement生成品質評価セット
- OpenAI providerによるRequirement生成
- Issue/OpenAPI生成条件とのapproved Requirement接続
- Requirement Workspaceの差分、未決事項、リスク強調UX

## 次アクション

- Requirement承認APIとReview gateを追加する
- 生成品質評価セットを作る
- Issue #4に進む前にRequirement approved状態をIssue/OpenAPI生成条件へ接続する
