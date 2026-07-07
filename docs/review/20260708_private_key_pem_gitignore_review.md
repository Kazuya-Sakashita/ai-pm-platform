# 2026-07-08 private-key.pem Git管理除外レビュー

## 評価日時

2026-07-08 00:00:00 JST

## 評価担当

Codex L1ロール分離レビュー

- Security Engineer
- DevOps
- CTO
- QA

外部AIレビュー: 未実施。Claude / ChatGPT等の外部AIレビューは追加待ち。

## Issue番号

ISSUE-070 / GitHub Issue #113

## 対象成果物

- `.gitignore`
- `docs/issue/ISSUE-070_private_key_pem_gitignore.md`

## 使用フレームワーク

- STRIDE
- OWASP Top 10
- ISO25010

## 評価サマリー

`xxxxx.private-key.pem` のような秘密鍵ファイルは、GitHub App秘密鍵や外部連携credentialとして使われる可能性がある。Git管理対象に入るとInformation DisclosureとElevation of Privilegeの重大リスクになるため、`.gitignore` で明示的に除外する対応は妥当である。

今回の対応では `*.private-key.pem` に限定し、証明書や公開鍵用途の `*.pem` 全体を過剰にignoreしない方針にした。

## 良かった点

- 秘密鍵ファイル名パターンを明示的にignoreした。
- `*.pem` 全体をignoreせず、必要な公開証明書ファイルまで隠す過剰対応を避けた。
- 現時点で追跡中の `*.private-key.pem` / `*.pem` がないことを確認した。

## 改善点

- 既存Git履歴に秘密鍵が含まれていないことのsecret scanは未実施である。
- 実GitHub App秘密鍵が既に外部で共有済みの場合、rotation要否は別途確認が必要である。
- secret manager導入やローカル秘密鍵配置手順は未整備である。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | `*.private-key.pem` をGit管理対象外にする | 秘密鍵漏えい防止 |
| P1 | secret scanを必要に応じて実行 | 既存履歴確認 |
| P1 | GitHub App秘密鍵のrotation手順と接続 | 漏えい時の封じ込め |
| P2 | secret manager導入検討 | 長期運用強化 |

## 次アクション

1. GitHub Issueへ登録する。
2. PRを作成し、CIを確認する。
3. 必要に応じて既存履歴secret scanとkey rotationを別Issue化する。

## 判定

合格。

ただし、今回の対応は今後の誤コミット防止であり、過去履歴の漏えい確認や既存鍵rotationを代替しない。
