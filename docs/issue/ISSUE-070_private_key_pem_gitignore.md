# ISSUE-070: private-key.pemファイルをGit管理対象外にする

## Issue番号

ISSUE-070

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/113

登録日: 2026-07-08
状態: OPEN

## 背景

GitHub Appや外部連携の秘密鍵として `xxxxx.private-key.pem` のようなファイルをローカルに置く可能性がある。秘密鍵ファイルが誤ってGit管理されると、認証情報漏えい、GitHub App権限悪用、監査対応の重大リスクになる。

## 目的

`*.private-key.pem` をGit管理対象外にし、秘密鍵ファイルが誤ってコミットされるリスクを下げる。

## 完了条件

- `.gitignore` に `*.private-key.pem` を追加する
- 現時点で追跡中の `*.private-key.pem` / `*.pem` がないことを確認する
- セキュリティ観点のレビューを `docs/review/` へ保存する

## スコープ

- `.gitignore` 更新
- 追跡中ファイル確認
- Issue台帳とレビュー文書更新

## 非スコープ

- 既存Git履歴のsecret scan
- GitHub App秘密鍵のrotation
- secret manager導入
- `*.pem` 全体のignore

## 関連Issue

- ISSUE-004 / GitHub Issue #4
- ISSUE-068 / GitHub Issue #108

## 関連レビュー

- `docs/review/20260708_private_key_pem_gitignore_review.md`

## レビュー結果

2026-07-08更新: `.gitignore` に `*.private-key.pem` を追加した。`git ls-files '*private-key.pem' '*.pem'` で追跡中の該当ファイルがないことを確認した。

## 検証結果

- `git ls-files '*private-key.pem' '*.pem'`: 該当なし
- `rg --files -g '*.private-key.pem' -g '*.pem' -g '!node_modules'`: 該当なし
- `git diff --check`: success

## 優先度

P0

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後にGitHub Issue #113をクローズする。
