# ISSUE-019: Node/toolchain versionを固定する

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/19

登録日: 2026-06-30
同期方法: `scripts/sync-github-issues.rb --apply`

## 背景

ISSUE-017でRedocly CLIを導入したところ、現在のNode v22.7.0に対してRedocly CLIがNode v22.12以上またはv20.19以上を期待するengine warningを出した。

## 目的

Node.js、npm、Ruby、Rails、PostgreSQLなどのtoolchain versionを固定し、ローカルとCIで再現性のある開発環境を作る。

## 完了条件

- Node.js version方針が決まっている
- `.nvmrc` または `.node-version` がある
- package `engines` がある
- Ruby version方針が決まっている
- CIで同じversionを使う方針がある
- レビューが `docs/review/` に保存されている

## スコープ

- toolchain version policy
- Node/npm
- Ruby/Rails
- PostgreSQL
- CI version alignment

## 非スコープ

- Backend実装
- Frontend実装
- deploy環境構築

## 関連レビュー

- `docs/review/20260630_openapi_tooling_implementation_review.md`
- `docs/review/20260630_toolchain_version_policy_review.md`

## レビュー結果

tooling自体は動いたが、engine warningが残っている。CI導入前にversion固定が必要。

## 次アクション

- Node versionは `22.12.0` に決定済み
- `.node-version` を追加済み
- package `engines` を追加済み
- Toolchain方針は `docs/architecture/20260630_toolchain_version_policy.md` に保存済み
- レビューは `docs/review/20260630_toolchain_version_policy_review.md` に保存済み

## 進捗

完了。GitHub Issue同期済み。
