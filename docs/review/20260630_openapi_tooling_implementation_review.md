# 20260630_openapi_tooling_implementation_review

## 評価日時

2026-06-30 06:50 JST

## 評価担当

Codex as CTO, Tech Lead, Frontend Architect, DevOps, QA

## 使用フレームワーク

OpenAPI Review、DORA Metrics、ISO25010、SPACE Framework

## 評価対象

- `package.json`
- `package-lock.json`
- `redocly.yaml`
- `scripts/check-openapi.rb`
- `frontend/lib/api/schema.d.ts`
- `frontend/lib/api/client.ts`
- `docs/api/openapi.yaml`

## 良かった点

- `api:check`、`api:types`、`api:verify` が追加され、OpenAPIを契約として検証できるようになった。
- Redocly CLI、openapi-typescript、openapi-fetchが導入され、lint、型生成、client skeletonの流れができた。
- OpenAPI 3.1で不正だった `nullable: true` を削除し、Redoclyの構造エラーを解消した。
- `frontend/lib/api/schema.d.ts` がOpenAPIから生成された。
- `api:verify` は成功した。

## 改善点

- Redocly lintは55 warningsを出している。
- Node v22.7.0に対してRedocly CLIがNode v22.12以上またはv20.19以上を期待しているengine warningが出ている。
- `operationId` が未定義のendpointが多い。
- tag description、4XX response、license、server URLの警告が残っている。
- generated file差分チェックはまだscriptに入っていない。

## 優先順位

1. P0: Node versionを固定する
2. P0: OpenAPI lint warningsを解消する
3. P0: `api:verify` にgenerated diff checkを追加する
4. P1: CI workflowで `npm run api:verify` を実行する
5. P1: openapi-fetch clientをNext.js実装へ接続する

## 次アクション

- ISSUE-018としてOpenAPI lint warnings cleanupを登録する。
- ISSUE-019としてNode/toolchain version固定を登録する。
- Backend実装前にoperationIdと4XX responseを整える。

## Issue番号

ISSUE-017、ISSUE-018、ISSUE-019

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。

