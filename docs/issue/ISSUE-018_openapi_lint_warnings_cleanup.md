# ISSUE-018: OpenAPI lint warningsを解消する

## GitHub Issue

登録待ち。

理由: remote未設定、GitHub CLI token invalid。

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

## レビュー結果

tooling導入は成功したが、Redocly warningsが残っている。世界レベルのSaaS基準では実装前に契約品質を上げる必要がある。

## 次アクション

- operationIdを追加する
- tag descriptionを追加する
- 4XX responseを追加する
- Redocly rulesetを適切に調整する

