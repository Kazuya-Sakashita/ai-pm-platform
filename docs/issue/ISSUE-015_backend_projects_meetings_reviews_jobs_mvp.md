# ISSUE-015: BackendでProjects/Meetings/Reviews/JobsのMVPを実装する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/15

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

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
- `docs/review/20260630_backend_projects_meetings_reviews_jobs_implementation_review.md`

## レビュー結果

実装準備レビューでは、全migrationを一気に実装するのは重いと評価した。初回Backend実装はProjects/Meetings/Reviews/Jobsに絞る。

## 次アクション

- GitHub #15をcloseする
- ISSUE-002でMeeting ingest/minutes generationの上位フローへ接続する
- Backend CI導入時にPostgreSQL serviceとRSpecを追加する

## 進捗

完了。

2026-06-30 07:43 JST確認:

- Rails API scaffoldを `backend/` に作成済み
- PostgreSQL compose serviceを追加済み
- Projects create/list/show/update/archiveを実装済み
- Meetings create/list/showを実装済み
- Reviews create/list/resolve/accept-riskを実装済み
- Jobs showを実装済み
- Audit log placeholderを実装済み
- UUID primary key、PostgreSQL `pgcrypto` extension、主要migrationを追加済み
- request specs 10件を追加済み
- OpenAPIへProject update/archiveを反映し、TypeScript schemaを再生成済み
- `npm run api:verify`: 成功。OpenAPI contract warningなし。local Node engine warningのみ既知。
- `bundle exec ruby bin/rails db:prepare`: 成功
- `bundle exec rspec`: 10 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
