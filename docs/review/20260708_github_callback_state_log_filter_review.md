# GitHub callback stateログフィルタ実装レビュー

## 評価日時

2026-07-08 07:36:00 JST

## 評価担当

Codex、Security Engineer、Backend Architect、QA

## 使用フレームワーク

- STRIDE
- OWASP Top 10
- ISO25010
- Release Check

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 対象

- `backend/config/initializers/filter_parameter_logging.rb`
- `backend/spec/config/filter_parameter_logging_spec.rb`
- GitHub callback `state` parameter

## 実施内容

- Frontend callback full smoke中に、Rails development logの `Parameters` にcallback `state` 生値が出ることを検出した。
- `state` をRails parameter filterへ追加した。
- `ActiveSupport::ParameterFilter` で `state` が `[FILTERED]` になるspecを追加した。

## 良かった点

- live smokeで画面だけでなくサーバーログの漏えいリスクまで発見できた。
- `state` はone-timeでもcallback replay防止の信頼境界に関わるため、ログフィルタ対象にした判断は妥当。
- repositoryなど運用上必要な非secret情報はマスクせず、調査可能性を維持した。

## 改善点

- 既存レビューでは画面非露出は確認していたが、development logの `Parameters` までは確認対象に含めていなかった。
- `state` は一般的なパラメータ名のため、今後別用途のstateもログで読めなくなる。ただし安全側の影響であり許容できる。
- 既存のlive smoke runbookにはRails log上のstate非露出確認が明文化されていなかった。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | `state` ログフィルタ | callback replay防止境界の値をログへ残さない |
| P1 | live smoke runbookへログ確認を追加 | 再発防止 |
| P2 | 他の外部連携state名の棚卸し | 将来のSlack/Notion連携でも同様の漏えいを避ける |

## 次アクション

1. `state` ログフィルタをPR化する。
2. 関連RSpecと表示チェックを実行する。
3. ISSUE-004へcallback full smokeの追加リスクと修正を同期する。
4. live smoke runbookへRails log上の `state` フィルタ確認を追記済み。

## 判定

合格。

GitHub callback stateのログ露出リスクを修正し、回帰specで固定した。これにより、callback full smokeのセキュリティ証跡は一段強くなった。ただしGitHub webhook live delivery smokeとstaging/production worker smokeは未完了のため、ISSUE-004は継続OPENとする。

## Knowledge

画面に表示されないsecretでも、Railsのdevelopment logやrequest parameter logに出ることがある。OAuth/App callbackの `state`、`code`、`token` 系は、画面、API response、DBだけでなくログフィルタでも確認する。
