# 2026-07-07 failed job discard二人承認 設計レビュー

## 評価日時

2026-07-07 20:00 JST

## 評価担当

Codex L1ロール分離レビュー

- Security Engineer
- Backend Architect
- Frontend Architect
- QA / Release Manager
- Product Manager

## Issue番号

ISSUE-065 / GitHub Issue #100

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DDD
- ISO25010

## 対象

failed job discard承認request、承認/却下API、discard実行gate、AuditLog、OpenAPI、Frontend導線。

## G-STACK

- Goal: 高リスクdiscardを単独operatorのUI確認だけで実行できないようにする。
- Strategy: 承認状態を専用DB tableに保存し、discard APIで有効承認を必須にする。
- Tactics: 申請者と承認者の同一actor禁止、期限切れ拒否、対象ID/理由一致検証、消費済み化、safe AuditLogを実装する。
- Assessment: MVPとして妥当。ただしrelease owner overrideと外部承認連携は後続で必要。
- Conclusion: 実装へ進む。
- Knowledge: ISSUE-063の承認方針を実際のAPI gateへ接続する。

## 良かった点

- 承認を専用tableで第一級オブジェクト化し、期限、状態、申請者、承認者、消費者を追跡できる。
- UI確認ではなくAPIでdiscardを止める設計になっている。
- 同一actorによる申請と承認の兼任を禁止している。
- Project境界確認済みfailed jobだけを承認対象にする。
- approval note/rejection reason本文をAuditLogに出さず、presenceだけ保存する方針は情報露出を抑える。

## 改善点

- release owner単独overrideは未実装であり、緊急運用時の手順は別設計が必要。
- 承認依頼専用通知は未実装で、運用者は画面または既存通知を確認する必要がある。
- 承認期限は固定値で、Project別設定や環境別設定はできない。
- 専用Policy Objectはまだなく、Controllerのproject admin roleで制御している。
- 外部AI比較レビューは未実施で、Codex一次レビューとして保存する。

## STRIDE / OWASP確認

| 観点 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 条件付き合格 | JWT actorとProject membershipでactorを導出 |
| Tampering | 合格 | discard時にapproval ID、failed job ID、job ID、reason templateを再検証 |
| Repudiation | 合格 | request/approve/reject/expire/discardをAuditLogへ保存 |
| Information Disclosure | 合格 | note本文やraw exceptionはAuditLog/API sampleに出さない |
| Denial of Service | 要継続 | active approvalの重複を抑制。大量申請rate limitは共通429で継続 |
| Elevation of Privilege | P0 | 同一actor承認禁止、Project不一致拒否、admin以上のみ操作 |

## 優先順位

| 優先度 | 項目 | 判断 |
| --- | --- | --- |
| P0 | discard実行時の承認ID必須化 | 必須 |
| P0 | 同一actor承認禁止 | 必須 |
| P0 | 期限切れ、Project不一致、対象不一致拒否 | 必須 |
| P1 | Frontend承認状態表示と導線 | 必須 |
| P2 | release owner override、承認専用通知、Project別ポリシー | 後続 |

## 次アクション

1. `failed_job_discard_approvals` tableを追加する。
2. 承認Serviceとdiscard gateを実装する。
3. OpenAPIとFrontend導線を同期する。
4. RSpecとPlaywrightで承認flowを確認する。
5. 実装レビューを保存する。
