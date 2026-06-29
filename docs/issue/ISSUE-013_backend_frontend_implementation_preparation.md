# ISSUE-013: Backend/Frontend実装準備を行う

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/13

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

GitHub App実装準備、API/DB設計、静的プロトタイプQAが進み、次は実装に入る前の技術構成、リポジトリ構成、テスト方針、OpenAPI codegen、CI準備を決める必要がある。

## 目的

Backend/Frontend実装へ進む前に、モノレポ構成、Rails API、Next.js、OpenAPI lint/codegen、DB migration、テスト、CIの最小構成を決める。

## 完了条件

- モノレポ構成が定義されている
- Rails API初期構成が定義されている
- Next.js初期構成が定義されている
- OpenAPI lint/codegen方針がある
- DB migration方針がある
- RSpec/Playwright方針がある
- CI最小構成がある
- 実装準備レビューが `docs/review/` に保存されている

## スコープ

- 実装準備設計
- 技術構成
- テスト方針
- CI方針
- OpenAPI codegen

## 非スコープ

- アプリ本実装
- GitHub App実作成
- 本番deploy

## 関連レビュー

- `docs/review/20260630_github_app_implementation_preparation_review.md`
- `docs/review/20260630_static_prototype_visual_qa_review.md`
- `docs/review/20260630_backend_frontend_implementation_preparation_review.md`

## レビュー結果

実装に進むには、GitHub App、OpenAPI、DB、静的UIの準備が進んだ。ただし、リポジトリ構成、テスト、CI、codegenが未定義のため、このIssueで最後の実装準備を行う。

## 次アクション

- 実装準備設計は `docs/architecture/20260630_backend_frontend_implementation_preparation.md` に作成済み
- レビューは `docs/review/20260630_backend_frontend_implementation_preparation_review.md` に保存済み
- ISSUE-014としてモノレポscaffoldとOpenAPI検証基盤を登録済み
- ISSUE-015としてBackend Projects/Meetings/Reviews/Jobs MVPを登録済み

## 進捗

完了。GitHub Issue同期済み。
