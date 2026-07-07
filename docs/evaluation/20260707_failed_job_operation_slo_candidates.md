# failed job操作 SLO候補

## 対象

ISSUE-061 / GitHub Issue #90

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
| worker heartbeat | 60秒以内 | Queue health worker heartbeat | warning |
| oldest unfinished age | 300秒未満 | Queue health queue summary | warning |

## MVPで実装する範囲

- Queue health responseへ24時間のretry/discard/rejected件数を返す。
- Queue health panelにretry/discard/rejected件数を表示する。
- 操作履歴はAuditLogからsafe fieldsだけを返す。
- free-form理由、raw exception、backtrace、secret、他Project IDは返さない。

## 後続候補

- SLO閾値をrelease gateへ接続する。
- Slackまたは外部監視SaaSへの通知はISSUE-063 / GitHub Issue #96で追加する。
- ISSUE-062の明示マッピング後にretry後再失敗率を計測する。
- AuditLog viewerでfailed job操作履歴をfilter可能にする。
