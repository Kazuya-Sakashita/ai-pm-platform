# 20260630_toolchain_version_policy_review

## 評価日時

2026-06-30 06:50 JST

## 評価担当

Codex as CTO, DevOps, Tech Lead, QA

## 使用フレームワーク

DORA Metrics、SPACE Framework、ISO25010

## 評価対象

- `.node-version`
- `package.json`
- `docs/architecture/20260630_toolchain_version_policy.md`

## 良かった点

- Node.js versionをRedocly CLIの要求に合わせて `22.12.0` に固定した。
- `.node-version` と package `engines` でローカル/CIの基準を示した。
- Ruby/Rails/PostgreSQLはBackend scaffold時に固定する方針を明記した。
- PlaywrightとCIでのversion alignment方針が明文化された。

## 改善点

- 現在のローカルNodeは `v22.7.0` のため、まだ実環境は方針と一致していない。
- `.ruby-version` はBackend scaffold前のため未作成。
- Docker composeとCI workflowが未作成。
- npm package managerをnpmに固定するかpnpm/yarnにするかの比較は未実施。

## 優先順位

1. P0: CI導入時にNode `22.12.0` を使う
2. P0: Backend scaffold時に `.ruby-version` を追加する
3. P0: Docker composeでPostgreSQL tagを固定する
4. P1: package manager方針を必要に応じてADR化する

## 次アクション

- ISSUE-019は完了扱いにする。
- ISSUE-015またはBackend scaffold issueでRuby/Rails/PostgreSQLを固定する。
- CI追加時に`.node-version`を参照する。

## Issue番号

ISSUE-019、ISSUE-015

GitHub Issue: 登録待ち。理由: remote未設定、GitHub CLI token invalid。

