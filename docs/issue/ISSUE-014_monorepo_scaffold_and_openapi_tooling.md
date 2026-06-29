# ISSUE-014: モノレポ初期scaffoldとOpenAPI検証基盤を作る

## GitHub Issue

登録待ち。

理由: remote未設定、GitHub CLI token invalid。

## 背景

ISSUE-013でBackend/Frontend実装準備が完了した。実装へ進む前に、モノレポ構成、OpenAPI lint、型生成、基本CIの土台を作る必要がある。

## 目的

Rails APIとNext.jsを置けるモノレポ構成を作り、OpenAPIを契約として検証できる最小基盤を整える。

## 完了条件

- `backend/` ディレクトリがある
- `frontend/` ディレクトリがある
- `scripts/` ディレクトリがある
- OpenAPI parse checkがある
- OpenAPI `$ref` checkがある
- TypeScript型生成方針が決まっている
- CI最小方針が文書化または設定されている
- scaffoldレビューが `docs/review/` に保存されている

## スコープ

- モノレポ初期構成
- OpenAPI検証スクリプト
- 初期package/Gemfile方針
- CI準備

## 非スコープ

- 本格的なAPI実装
- GitHub App実装
- AI生成実装

## 関連レビュー

- `docs/review/20260630_backend_frontend_implementation_preparation_review.md`
- `docs/review/20260630_monorepo_scaffold_openapi_tooling_review.md`

## レビュー結果

実装準備レビューでは、初回実装を小さく切るべきと評価した。まずOpenAPIとモノレポ土台から始める。

## 次アクション

- モノレポscaffoldは `backend/`、`frontend/`、`scripts/` に作成済み
- OpenAPI検証スクリプトは `scripts/check-openapi.rb` に作成済み
- レビューは `docs/review/20260630_monorepo_scaffold_openapi_tooling_review.md` に保存済み
- ISSUE-016としてOpenAPI lint/codegen tool決定へ進める

## 進捗

完了。GitHub Issue同期のみ登録待ち。
