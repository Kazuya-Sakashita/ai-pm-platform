# 2026-07-07 failed job運用通知 実送信 設計レビュー

## 評価日時

2026-07-07 19:43 JST

## 評価担当

Codex L1ロール分離レビュー

- Security Engineer
- Backend Architect
- DevOps
- QA / Release Manager
- Product Manager

## Issue番号

ISSUE-064 / GitHub Issue #101

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## 対象

failed job操作実行通知、release gate warning/block通知、通知失敗AuditLog、通知Gateway設計。

## G-STACK

- Goal: warning/blockやretry/discard実行を運用者へ届け、検知遅れを減らす。
- Strategy: 通知Gatewayとfailed job通知Serviceを分離し、secretを扱う境界を最小化する。
- Tactics: webhook URL未設定時はno-op、payloadはallowlist、通知失敗はAuditLog、release gate通知はcooldownで重複抑制する。
- Assessment: MVPとして妥当。ただしProject別通知設定、再送、通知状態DBは後続で必要。
- Conclusion: 実装へ進む。
- Knowledge: ISSUE-063のnotification policyを実送信基盤へ接続する。

## 良かった点

- ControllerやModelに外部通知を入れず、Service ObjectとGatewayへ分離する方針は保守性が高い。
- webhook URL未設定をno-opにすることで、CI、local、stagingの安全性を保てる。
- payload allowlistにより、raw exception、backtrace、token、database URL、DM本文、AI promptを通知へ混入させにくい。
- 通知失敗をAuditLogに残すため、release evidenceとして追跡しやすい。
- release gate通知にcooldownを入れるため、Queue health確認による通知過多を抑えられる。

## 改善点

- 通知再送jobがないため、一時的なwebhook障害では手動確認が必要になる。
- 通知先は環境変数単位であり、Project別や重大度別の通知先切り替えはできない。
- release gate通知のdedupeはAuditLogベースであり、専用の通知状態tableではない。
- Slack以外のチャネル向けformat最適化は未実装である。
- 外部AI比較レビューは未実施で、Codex一次レビューとして保存する。

## STRIDE / OWASP確認

| 観点 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 要注意 | webhook URLは環境変数のみ。APIレスポンスへ出さない |
| Tampering | 条件付き合格 | payloadはサーバー側allowlistで生成する |
| Repudiation | 合格 | 成功/失敗をAuditLogへ保存する |
| Information Disclosure | P0 | secret、raw exception、DM本文、AI promptをpayloadから除外する |
| Denial of Service | 要継続 | cooldownで通知過多を抑える。再送制御は後続 |
| Elevation of Privilege | 条件付き合格 | 通知は既存の認可済み操作とQueue health評価からのみ発火する |

## 優先順位

| 優先度 | 項目 | 判断 |
| --- | --- | --- |
| P0 | secret非露出、safe payload allowlist | 必須 |
| P0 | 通知失敗AuditLog | 必須 |
| P1 | 操作成功時通知 | 必須 |
| P1 | release gate warning/block通知 | 必須 |
| P2 | 再送、Project別通知設定、通知状態DB | 後続 |

## 次アクション

1. `Operations::NotificationGateway` を追加する。
2. `Operations::FailedJobNotificationService` を追加する。
3. `FailedJobOperationService` と `QueueHealthQuery` から依存注入で呼び出す。
4. RSpecでno-op、送信成功、送信失敗AuditLog、cooldown、safe payloadを確認する。
5. 実装レビューを保存する。
