# ISSUE-015: BackendでProjects/Meetings/Reviews/JobsのMVPを実装する

## GitHub Issue

登録待ち。

理由: remote未設定、GitHub CLI token invalid。

## 背景

AI PM Platformの最初の実装価値は、会議ログを保存し、生成物とレビューゲートを追跡できることにある。GitHub AppやAI生成の本実装前に、Projects、Meetings、Reviews、Jobsの基礎を作る。

## 目的

Rails APIでProjects、Meetings、Reviews、Jobsの最小実装を行い、FrontendとAI/GitHub連携の土台を作る。

## 完了条件

- Projects CRUDがある
- Meetings create/list/showがある
- Reviews create/list/resolveがある
- Jobs showがある
- audit log placeholderがある
- request specがある
- OpenAPIとレスポンスが大きく乖離していない
- Backend実装レビューが `docs/review/` に保存されている

## スコープ

- Rails API最小実装
- PostgreSQL schema
- Request specs
- OpenAPI alignment

## 非スコープ

- AI生成実装
- GitHub publish実装
- 本番認証
- Frontend実装

## 関連レビュー

- `docs/review/20260630_backend_frontend_implementation_preparation_review.md`

## レビュー結果

実装準備レビューでは、全migrationを一気に実装するのは重いと評価した。初回Backend実装はProjects/Meetings/Reviews/Jobsに絞る。

## 次アクション

- ISSUE-014完了後に着手する
- DB migrationを最小化する
- request specを先に書く

