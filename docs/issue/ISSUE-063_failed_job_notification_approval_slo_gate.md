# ISSUE-063: failed job操作の通知、二人承認、SLOアラートをrelease gateへ接続する

## Issue番号

ISSUE-063

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/96

## 背景

ISSUE-061では、failed job操作のMVP安全制御として、action別理由テンプレート、discard確認必須、AuditLog由来の運用履歴、24時間retry/discard/rejected件数、SLO候補定義を追加した。

しかし、世界レベルSaaSの本番運用では、高リスク操作の二人承認、操作発生時の通知、SLO閾値超過時のアラート、release gateへの接続が必要になる。特にdiscardは不可逆に近く、retryも外部API再実行や重複副作用を起こし得るため、単独operator判断だけでは成熟度が足りない。

## 目的

failed job操作を本番運用に耐える監視、承認、通知フローへ引き上げ、誤操作、検知遅れ、説明責任不足を減らす。

## 完了条件

- 高リスクdiscard操作の二人承認またはowner承認の要否が設計されている
- Slackまたは運用通知チャンネルへの通知方針が設計されている
- failed job操作SLO候補がrelease gateまたはrunbookへ接続されている
- retry/discard/rejected件数の閾値超過時の対応手順が定義されている
- ISSUE-062完了後にretry後再失敗率を計測する方針が定義されている
- OpenAPI、Backend、Frontend、AuditLog、RSpec、Playwrightの変更範囲が整理されている
- 設計レビューと実装レビューが `docs/review/` に保存されている

## スコープ

- failed job操作通知設計
- 高リスクdiscardの承認フロー設計
- SLO閾値とrelease gate接続
- retry後再失敗率の計測方針
- AuditLog viewerまたは運用履歴の検索導線検討
- 必要なOpenAPI、Backend、Frontend、テスト更新

## 非スコープ

- ISSUE-061で完了したaction別理由テンプレート
- ISSUE-061で完了したdiscard確認必須
- ISSUE-062のProduct JobとSolid Queue job明示マッピング保存
- 外部監視SaaSの本格導入
- bulk retry/discard

## 関連レビュー

- `docs/review/20260707_failed_job_operation_safety_design_review.md`
- `docs/review/20260707_failed_job_operation_safety_implementation_review.md`
- `docs/evaluation/20260707_failed_job_operation_slo_candidates.md`

## レビュー結果

P2。ISSUE-061のMVPは合格見込みだが、本番release gate観点では通知、承認、SLOアラートが不足している。Security Engineer観点では、高リスクdiscardを単独operatorのUI確認だけで完結させる状態は長期運用では不十分である。

## 次アクション

1. discard操作のリスクレベルを整理し、二人承認対象を定義する。
2. Slack通知、AuditLog viewer、release runbookのどこへ最初に接続するか比較する。
3. SLO閾値超過時の対応手順をrelease runbookへ追加する。
4. ISSUE-062の明示マッピング完了後、retry後再失敗率の計測設計を具体化する。
5. 設計レビューを保存してからOpenAPI更新へ進む。
