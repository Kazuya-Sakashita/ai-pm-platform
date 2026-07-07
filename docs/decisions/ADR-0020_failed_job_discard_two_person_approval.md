# ADR-0020: failed job discard二人承認DB/API強制

## Status

Accepted

## Date

2026-07-07

## Context

failed job discardは不可逆性が高く、調査可能な情報を減らす可能性がある。ISSUE-063ではrelease gate上に二人承認方針を表示し、ISSUE-064では通知MVPを追加した。しかし、APIは承認状態をDBで検証しておらず、単独operatorの確認だけでdiscardできる余地が残っていた。

世界レベルSaaS基準では、本番高リスク操作はUI確認だけでは不十分であり、監査可能な承認event、期限、承認者、対象ID、Project境界をAPIで強制する必要がある。

## Decision

`failed_job_discard_approvals` tableを追加し、failed job discardに二人承認gateを導入する。

主な方針:

- failed job discard承認はProjectに紐づくDB recordとして保存する。
- 承認requestは、Project境界確認済みfailed job、破棄理由テンプレート、リスク確認済みの場合のみ作成する。
- 承認者は申請者と別actorでなければならない。
- 承認には期限を持たせ、期限切れはAPIで拒否する。
- discard実行時は `discard_approval_id` を必須にし、Project、failed job ID、Solid Queue job ID、reason template、承認状態、有効期限、申請者と承認者の差分を検証する。
- 承認はdiscard成功後に `consumed` へ更新し、再利用を防ぐ。
- AuditLogには承認者、role、理由テンプレート、期限、対象safe ID、approval note/rejection reasonの有無だけを保存し、本文は保存しない。

## Alternatives

### UI確認checkboxだけを強化する

実装は最小だが、API直叩きや単独operatorの誤操作を防げない。監査証跡としても弱いため採用しない。

### AuditLogだけで承認状態を表現する

追加tableなしで始められるが、期限、状態遷移、対象一致検証、再利用防止のqueryが複雑になる。承認を第一級オブジェクトとして扱うため採用しない。

### 既存Review modelへ流用する

Review Centerとの統合余地はあるが、failed job discardは運用操作であり、対象がSolid Queue failed executionである。汎用Reviewへ寄せると運用gateの責務が曖昧になるため、MVPでは専用tableにする。

### release owner単独overrideを先に実装する

緊急時には有効だが、単独overrideは濫用リスクがある。まず二人承認を標準化し、release owner overrideは別Issueでリスク受容と運用手順を明示してから検討する。

## Consequences

良い影響:

- failed job discardを単独operatorのUI確認だけで実行できなくなる。
- 申請者、承認者、消費者、期限、対象safe IDが追跡できる。
- OpenAPI、Backend、Frontend、E2Eが承認flowを共有する。
- release gateの承認方針が実際のAPI制御へ接続される。

注意点:

- 緊急時のrelease owner単独overrideは未実装である。
- 承認通知や外部承認ワークフローとの連携はISSUE-064の通知MVPに留まり、承認専用通知は未実装である。
- Project別承認ポリシーや承認期限設定UIは未実装である。

## Follow-up

- ISSUE-065 / GitHub Issue #100でMVP実装する。
- release owner override、承認専用通知、承認期限設定UIは後続Issueとして必要性を再評価する。
