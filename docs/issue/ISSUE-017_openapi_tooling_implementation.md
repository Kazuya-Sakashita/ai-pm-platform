# ISSUE-017: OpenAPI toolingを実装する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/17

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

ISSUE-016でOpenAPI lint/codegen toolingとしてRedocly CLI、openapi-typescript、openapi-fetchを採用した。次にroot package scripts、Redocly設定、型生成ファイル、client skeletonを実装する必要がある。

## 目的

OpenAPIを契約としてlintし、Frontend TypeScript型とclientを生成/利用できる最小toolingを実装する。

## 完了条件

- root `package.json` がある
- `api:check` scriptがある
- `api:types` scriptがある
- `api:verify` scriptがある
- Redocly設定がある
- `frontend/lib/api/schema.d.ts` が生成されている
- `frontend/lib/api/client.ts` skeletonがある
- レビューが `docs/review/` に保存されている

## スコープ

- OpenAPI tooling
- package scripts
- generated types
- frontend API client skeleton

## 非スコープ

- Backend実装
- Frontend画面実装
- CI workflow

## 関連レビュー

- `docs/review/20260630_openapi_lint_codegen_decision_review.md`
- `docs/review/20260630_openapi_tooling_implementation_review.md`

## レビュー結果

ADRとしての採用判断は妥当。ただし実装前にpackage scripts、ruleset、型生成、client skeletonが必要。

## 次アクション

- root packageは `package.json` に作成済み
- tooling dependenciesはnpm install済み
- 型生成は `frontend/lib/api/schema.d.ts` に実行済み
- `api:verify` は成功済み
- Redocly warnings cleanupはISSUE-018へ切り出し
- toolchain version固定はISSUE-019へ切り出し

## 進捗

完了。GitHub Issue同期済み。
