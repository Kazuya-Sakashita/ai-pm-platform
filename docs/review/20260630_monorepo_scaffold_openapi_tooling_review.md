# 20260630_monorepo_scaffold_openapi_tooling_review

## 評価日時

2026-06-30 06:50 JST

## 評価担当

Codex as CTO, Tech Lead, DevOps, Backend Architect, Frontend Architect, QA

## 使用フレームワーク

DORA Metrics、SPACE Framework、ISO25010、OpenAPI Review

## 評価対象

- `.gitignore`
- `backend/README.md`
- `frontend/README.md`
- `scripts/check-openapi.rb`
- `docs/api/openapi.yaml`

## 良かった点

- `backend/`、`frontend/`、`scripts/` の初期ディレクトリが作成され、モノレポ化の入口ができた。
- OpenAPI YAML parseとcomponent `$ref` の簡易チェックを依存なしRubyスクリプトで実行できる。
- `.gitignore` にnode_modules、Next.js生成物、backend tmp/log/vendor、QA画像を追加し、初期のノイズを抑えた。
- Rails/Next本体をまだ入れず、実装前の検証基盤から小さく始めている。

## 改善点

- Rails APIとNext.jsの実scaffoldは未実施。
- OpenAPI lintは簡易チェックであり、Redocly/Spectralのような本格lintではない。
- TypeScript型生成は未実装。
- CI設定ファイルは未作成。
- `.env.example` がまだない。

## 優先順位

1. P0: OpenAPI lint/codegen toolを決定する
2. P0: Rails API scaffoldを作成する
3. P0: Next.js scaffoldを作成する
4. P0: `.env.example` を作成する
5. P1: CI workflowを追加する

## 次アクション

- ISSUE-016としてOpenAPI lint/codegen toolのADRを作成する。
- ISSUE-015でBackend最小実装へ進む前に、Rails API scaffoldを作る。
- FrontendはBackend最小APIの後、静的プロトタイプをNext.jsへ移植する。

## Issue番号

ISSUE-014、ISSUE-015、ISSUE-016

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。

