# ISSUE-061: failed job操作の安全制御と通知/SLOを強化する

## Issue番号

ISSUE-061

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/90

## 背景

ISSUE-056では、project admin限定、理由テンプレート必須、AuditLog保存、raw exception非表示を満たすfailed job単体操作MVPを追加した。

しかし、discardは不可逆に近く、retryも外部API再実行や重複副作用を起こす可能性がある。長期運用では、action別理由テンプレート、確認導線、通知、SLO、操作失敗時のアラートが必要になる。

## 目的

failed job操作を本番SaaS運用に耐える安全制御へ引き上げ、誤操作、説明不足、検知遅れを減らす。

## 完了条件

- retry用とdiscard用の理由テンプレートがaction別に分離されている
- discard操作に追加確認またはリスク確認導線がある
- 操作結果と失敗を運用者が追跡しやすい通知または運用履歴に接続されている
- failed job件数、再実行回数、破棄回数、再失敗率などのSLO候補が定義されている
- UI、API、AuditLogがfree-form秘密情報を保存しない
- RSpec、Playwright、レビュー文書が更新されている

## スコープ

- action別理由テンプレート
- discard確認導線
- 操作結果の通知または運用履歴設計
- SLO/メトリクス候補の定義
- UI/API/AuditLogの安全性レビュー

## 非スコープ

- Project境界の厳密化
- staging/production worker smoke
- bulk retry/discard
- Slack連携の本実装
- 外部監視SaaS連携

## 関連レビュー

- `docs/review/20260707_failed_job_retry_discard_operations_design_review.md`
- `docs/review/20260707_failed_job_retry_discard_operations_implementation_review.md`
- `docs/review/20260707_failed_job_followup_issue_split_review.md`

## レビュー結果

P2。ISSUE-056のMVP完了後に取り組むべき運用品質改善である。現時点のMVPをブロックするほどではないが、世界レベルSaaSの運用UIとしては、誤操作防止、通知、SLOが不足している。

## 次アクション

1. failed job操作のaction別リスクを整理する。
2. retry/discard別の理由テンプレートと確認導線を設計する。
3. 通知、運用履歴、SLO候補を比較し、最小実装範囲を決める。
4. OpenAPI、Backend、Frontend、テストの更新計画を作る。
