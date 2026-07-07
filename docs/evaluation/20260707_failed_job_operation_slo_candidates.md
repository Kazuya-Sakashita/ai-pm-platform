# failed job操作 SLO候補

## 対象

ISSUE-061 / GitHub Issue #90、ISSUE-063 / GitHub Issue #96

## 目的

failed job retry/discard操作を継続監視できるように、最小SLO候補と計測元を定義する。

## SLO候補

| 指標 | 候補目標 | 計測元 | 初期扱い |
| --- | --- | --- | --- |
| failed job残存件数 | business hours中にProject別5件未満 | Queue health `failed_executions.count` | warning |
| retry件数 | 24時間で10件未満 | AuditLog `operations.failed_job_retried` | trend |
| discard件数 | 24時間で5件未満 | AuditLog `operations.failed_job_discarded` | warning |
| 境界拒否件数 | 24時間で0件 | AuditLog `operations.failed_job_project_boundary_rejected` | security warning |
| retry後再失敗率 | 10%未満 | ISSUE-062の明示マッピング後に計測 | future |
| 明示mapping未使用sample数 | Project別0件 | Queue health `failed_job_samples.product_job_mapping_source` | warning |
| worker heartbeat | 60秒以内 | Queue health worker heartbeat | warning |
| oldest unfinished age | 300秒未満 | Queue health queue summary | warning |

## ISSUE-063でrelease gateへ接続した範囲

- Queue health responseへ `failed_job_release_gate` を追加した。
- `worker_heartbeat`、`oldest_unfinished_age`、`failed_execution_count`、`retry_count`、`discard_count`、`boundary_rejected_count`、`mapping_fallback_sample_count`、`retry_refailure_rate` をgate checkとして返す。
- `boundary_rejected_count` は1件以上で `blocked` とし、release停止とSecurity Engineer確認を求める。
- `retry_refailure_rate` は `not_measured` として表示し、後続で `job_queue_mappings` とAuditLogから計測する。
- notification policyはsafe metadataのみを許可し、`raw_exception`、`backtrace`、`serialized_arguments`、`token`、`database_url`、`dm_body`、`ai_prompt` を禁止する。

## MVPで実装する範囲

- Queue health responseへ24時間のretry/discard/rejected件数を返す。
- Queue health panelにretry/discard/rejected件数を表示する。
- 操作履歴はAuditLogからsafe fieldsだけを返す。
- free-form理由、raw exception、backtrace、secret、他Project IDは返さない。
- `failed_job_release_gate` をQueue health responseとFrontendへ表示し、release ownerがpass/warning/blockedを判断できるようにする。

## 後続候補

- Slackまたは外部監視SaaSへの実通知を追加する。
- discard二人承認をDB/APIで強制する。
- ISSUE-062の明示マッピング後にretry後再失敗率を計測する。
- AuditLog viewerでfailed job操作履歴をfilter可能にする。
