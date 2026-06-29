# ISSUE-018: OpenAPI lint warningsを解消する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/18

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

ISSUE-017でRedocly CLIを導入し、`api:verify` は成功した。しかしRedocly lintで55 warningsが残っている。

## 目的

OpenAPIのoperationId、tag description、4XX response、license、server URL警告を解消し、Backend/Frontend実装前のAPI契約品質を上げる。

## 完了条件

- 全operationにoperationIdがある
- 全tagにdescriptionがある
- 必要なoperationに4XX responseがある
- info.licenseがある
- server URL方針が決まっている
- `npm run api:verify` がwarningsなし、または許容warningが明文化されている
- レビューが `docs/review/` に保存されている

## スコープ

- OpenAPI warnings cleanup
- Redocly ruleset調整
- API contract品質改善

## 非スコープ

- Backend実装
- Frontend実装
- API機能追加

## 関連レビュー

- `docs/review/20260630_openapi_tooling_implementation_review.md`
- `docs/review/20260630_openapi_lint_warnings_cleanup_review.md`

## レビュー結果

tooling導入は成功したが、Redocly warningsが残っている。世界レベルのSaaS基準では実装前に契約品質を上げる必要がある。

## 次アクション

- ISSUE-015のBackend実装前に、生成済みTypeScript schemaを利用する
- local Nodeを `.node-version` の `22.12.0` 以上へ合わせる
- Backend実装時にOpenAPI contract testをCIへ追加する

## 進捗

完了。

2026-06-30 07:25 JST確認:

- 全operationへ `operationId` を追加済み
- 全tagへdescriptionを追加済み
- 必要なoperationへ4XX responseを追加済み
- `info.license` と `identifier` を追加済み
- server URLは `.test` placeholderへ変更し、local devはclient側の `NEXT_PUBLIC_API_BASE_URL` で上書きする方針に変更済み
- `npm run api:verify`: OpenAPI lint warningなし
- local Node `v22.7.0` によるRedocly engine warningのみ残存。これはOpenAPI契約warningではなくISSUE-019のtoolchain整合課題として扱う。

2026-06-30 07:27 JST確認:

- GitHub #18 close済み
- close commentにcommit `bf42674` を記録済み
