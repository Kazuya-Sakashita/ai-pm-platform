# ISSUE-055: GitHub ActionsのNode.js 20 deprecated annotationを解消する

## Issue番号

ISSUE-055

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/78

## 背景

PR #77のGitHub Actionsで、`actions/checkout@v4` と `actions/setup-node@v4` がNode.js 20を対象にしており、runner側でNode.js 24へ強制されるdeprecated annotationが表示された。

CI自体は成功しているが、将来のGitHub Actions基盤変更で警告がエラー化または互換性問題になる可能性がある。

## 目的

CIのNode.js runtime annotationを解消し、GitHub Actions基盤の将来互換性を維持する。

## 完了条件

- GitHub ActionsでNode.js 20 deprecated annotationが出ない
- `verify` jobが成功する
- 変更理由と検証結果が `docs/review/` に保存されている

## スコープ

- `.github/workflows/` のactions version更新
- CI verifyの確認
- レビュー文書の保存

## 非スコープ

- Node.jsアプリケーション実行バージョンの変更
- npm package major upgrade
- frontend設計変更

## 関連レビュー

- `docs/review/20260707_security_auth_audit_baseline_closure_review.md`
- `docs/review/20260707_ci_node20_deprecation_annotation_review.md`

## レビュー結果

P2。現時点でCIは成功しているため緊急ではないが、世界レベルSaaSのrelease gateとしてCI warningを放置しない。

2026-07-07のCI基盤レビューで、`actions/checkout`、`actions/setup-node`、失敗時artifact保存に使う `actions/upload-artifact` の公式最新リリースを確認し、workflowのaction major versionのみ更新する方針を承認した。

## 次アクション

1. PRで `verify` jobを実行し、annotationが解消されているか確認する。
2. CI成功後、GitHub Issue #78へ検証結果をコメントする。
3. 問題なければIssue #78をクローズする。
