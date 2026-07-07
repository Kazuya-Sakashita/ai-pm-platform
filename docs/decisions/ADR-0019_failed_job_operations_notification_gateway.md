# ADR-0019: failed job運用通知Gateway

## Status

Accepted

## Date

2026-07-07

## Context

ISSUE-063ではQueue healthへfailed job release gateを追加し、通知対象とsafe payload方針を可視化した。しかし、運用者が画面を見ていない場合はwarning/blockやretry/discard実行を検知できない。

ISSUE-064では、Slackまたは運用通知チャンネルへMVP通知を送る必要がある。一方で、webhook URL、token、DB接続情報、raw exception、backtrace、DM本文、AI入力全文をAPIレスポンス、ログ、レビュー文書へ出してはならない。

## Decision

failed job運用通知は、`Operations::NotificationGateway` と `Operations::FailedJobNotificationService` に分離する。

主な方針:

- `OPERATIONS_NOTIFICATION_WEBHOOK_URL` が未設定の場合は安全なno-opにする。
- `OPERATIONS_NOTIFICATION_CHANNEL` は論理チャンネル名として扱い、未設定時は `operations` とする。
- GatewayはSlack incoming webhook互換の `text` payloadを送る。ただし実装上は汎用webhookとして扱い、ControllerやModelへSlack固有処理を入れない。
- 通知payloadはallowlist方式で絞る。
- 許可する主なfieldは、Project ID、failed job ID、job ID、queue name、class name、action、reason template、operator actor ID、AuditLog action、release gate status、safe check summaryに限定する。
- 通知失敗時は `operations.failed_job_notification_failed` としてAuditLogへsafe metadataのみ保存する。
- 通知成功時は `operations.failed_job_notification_sent` としてAuditLogへ保存する。
- release gate warning/block通知はcooldownを設け、同一payloadの重複通知を抑制する。

## Alternatives

### Controllerから直接Slack webhookを呼ぶ

実装は短いが、Controllerが外部通知、payload制御、失敗監査を抱える。今後Slack以外へ広げる時に責務が崩れるため採用しない。

### `FailedJobOperationService` にHTTP送信を直接書く

操作成功時通知だけなら成立するが、release gate warning/block通知とpayload sanitizationを共有しにくい。操作Serviceの責務が大きくなるため採用しない。

### 本格的な通知基盤、再送job、通知設定DBを先に作る

長期的には必要だが、ISSUE-064のMVPには重い。通知先の環境変数管理、safe payload、失敗AuditLogを先に実装し、再送や通知設定UIは後続に分ける。

### webhook URLをAPIレスポンスや管理画面へ出す

秘密情報露出リスクが高いため採用しない。webhook URLは環境変数でのみ扱う。

## Consequences

良い影響:

- failed job操作とrelease gateの重要イベントを運用チャンネルへ送れる。
- webhook URL未設定の開発環境やCIでも安全に動く。
- 通知失敗がAuditLogに残り、release ownerが手動確認できる。
- Slack以外の運用通知チャンネルへ差し替えやすい。

注意点:

- incoming webhookへの実送信は環境変数設定が前提である。
- 通知再送、通知設定UI、通知先のProject別切り替えは未実装である。
- Queue health取得時のrelease gate通知はcooldownで抑制するが、厳密な通知状態管理はDB設計の後続課題である。

## Follow-up

- ISSUE-064 / GitHub Issue #101でMVP実装する。
- ISSUE-065 / GitHub Issue #100でdiscard二人承認をDB/APIで強制する。
- ISSUE-066 / GitHub Issue #99でretry後再失敗率を実測する。
