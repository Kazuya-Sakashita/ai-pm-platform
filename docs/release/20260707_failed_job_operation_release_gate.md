# failed job操作リリースゲート

## 対象

ISSUE-063 / GitHub Issue #96

## 目的

failed job retry/discard操作を、通知、承認、SLO確認、release判定へ接続する。実Slack送信や二人承認DBは本IssueのMVPでは実装せず、Queue health API/UIでrelease gate判定と安全な通知方針を確認できる状態にする。

## リリースゲート判定

| key | 閾値 | status | 対応 |
| --- | --- | --- | --- |
| `worker_heartbeat` | 60秒以内 | warning | worker processとqueue database接続を確認する |
| `oldest_unfinished_age` | 300秒未満 | warning | queue詰まり、worker数、外部API制限を確認する |
| `failed_execution_count` | 5件未満 | warning | release ownerが残存理由と次回確認時刻を記録する |
| `retry_count` | 24時間10件未満 | warning | retry理由と再失敗有無を確認し、必要なら再実行を停止する |
| `discard_count` | 24時間5件未満 | warning | discard対象、承認者、復旧不要の根拠を確認する |
| `boundary_rejected_count` | 0件 | blocked | Security EngineerがProject境界、mapping、権限を確認するまでrelease停止 |
| `mapping_fallback_sample_count` | 0件 | warning | 既存job由来かmapping保存失敗かを確認する |
| `retry_refailure_rate` | 10%未満 | not_measured | `job_queue_mappings` とAuditLogで後続計測する |

## 通知方針

- 通知チャンネルは論理名 `operations` とする。
- webhook URL、token、DB接続情報、DM本文、AI入力全文はAPIレスポンス、通知payload、レビュー文書へ保存しない。
- 通知対象は、release gate warning、release gate blocked、failed job操作実行、通知失敗とする。
- 通知失敗時はAuditLogまたはrelease evidenceへsafe metadataのみを残し、release ownerが手動確認する。

## 承認方針

| 操作 | 初期方針 |
| --- | --- |
| retry | admin以上、理由テンプレートと副作用確認をAuditLogへ保存 |
| discard | ownerまたはrelease owner、二人承認またはrelease owner承認を証跡化 |
| production failed job操作 | 観測のみを既定。実操作はincident commanderまたはrelease owner承認、Project特定、AuditLog確認が必須 |

## 完了条件

- Queue health APIが `failed_job_release_gate` を返す。
- Frontend運用監視でリリースゲート、通知要否、破棄承認方針、主要checkを表示する。
- `docs/review/` に設計レビューと実装レビューを保存する。
- staging/production smokeでは本runbookと `20260704_solid_queue_staging_worker_smoke_runbook.md` を併用する。
