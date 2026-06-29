# 20260630_openapi_lint_codegen_decision_review

## 評価日時

2026-06-30 06:50 JST

## 評価担当

Codex as CTO, Tech Lead, Frontend Architect, Backend Architect, DevOps, QA

## 使用フレームワーク

ADR、DORA Metrics、SPACE Framework、ISO25010、OpenAPI Review

## 評価対象

`docs/decisions/ADR-0004_openapi_lint_codegen_tooling.md`

## 良かった点

- Redocly CLI、openapi-typescript、openapi-fetchの役割分担が明確。
- `scripts/check-openapi.rb` をfallbackとして残す判断により、Node依存が壊れても最低限の検証を続けられる。
- generated fileの配置とCI方針が定義され、API駆動開発を実装運用へ接続している。
- 手書きclientを避ける判断は、FrontendとOpenAPIの乖離防止に有効。

## 改善点

- root `package.json` が未作成。
- Redocly rulesetが未定義。
- 実際の型生成は未実行。
- CI workflowはまだ未作成。
- Node.js version requirementをプロジェクトで固定していない。

## 優先順位

1. P0: root `package.json` とAPI scriptsを作成する
2. P0: Redocly設定を追加する
3. P0: `frontend/lib/api/schema.d.ts` を生成する
4. P0: Node.js versionを固定する
5. P1: CI workflowを追加する

## 次アクション

- ISSUE-017としてOpenAPI tooling実装を登録する。
- ISSUE-014のscaffoldにpackage scriptsを追加する。
- Frontend scaffold時にopenapi-fetch clientを組み込む。

## Issue番号

ISSUE-016、ISSUE-017

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。

