# ISSUE-016: OpenAPI lint/codegen toolを決定する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/16

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

ISSUE-014で依存なしのOpenAPI parse/ref checkは作成したが、本格的なlintとTypeScript client生成は未決である。API駆動開発を守るには、実装前にtoolingを決定する必要がある。

## 目的

OpenAPI lint、TypeScript型生成、Frontend API client、Backend contract checkのツールを比較し、MVPで採用する構成を決める。

## 完了条件

- OpenAPI lint toolが決定している
- TypeScript型生成toolが決定している
- generated fileの配置が決まっている
- CIで差分検出する方針がある
- ADRが `docs/decisions/` に保存されている
- レビューが `docs/review/` に保存されている

## スコープ

- Redocly/Spectral等の比較
- openapi-typescript等の比較
- CI方針
- generated file運用

## 非スコープ

- Backend実装
- Frontend実装
- API仕様追加

## 関連レビュー

- `docs/review/20260630_monorepo_scaffold_openapi_tooling_review.md`
- `docs/review/20260630_openapi_lint_codegen_decision_review.md`

## レビュー結果

現状のRubyスクリプトは有効だが簡易チェックであり、世界レベルのSaaS品質としてはlint/codegen/contract checkが必要。

## 次アクション

- lint/codegen候補を比較済み
- ADRは `docs/decisions/ADR-0004_openapi_lint_codegen_tooling.md` に作成済み
- ISSUE-017としてOpenAPI tooling実装へ進める

## 進捗

完了。GitHub Issue同期済み。
