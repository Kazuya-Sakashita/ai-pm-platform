# failed job retry/discard worker smoke evidence template

## 評価日時

YYYY-MM-DD HH:MM:SS TZ

## 評価担当

- Operator:
- Reviewer:
- Security approver:
- Release approver:

## 使用フレームワーク

- STRIDE
- DORA Metrics
- ISO25010

## Issue番号

- ISSUE-060 / GitHub #89
- 関連: ISSUE-004 / GitHub #4

## 実施状況

- [ ] 実施済み
- [ ] 未実施
- [ ] blocked

未実施またはblockedの場合:

- 待ち理由:
- owner:
- target environment:
- next execution date:

## 対象環境

- environment:
- application URL:
- API URL:
- commit SHA:
- deploy ID:
- worker process command:
- `QUEUE_DATABASE_URL` presence confirmed without value: yes / no

## Queue Health Before

- checked_at:
- status:
- worker count:
- stale worker count:
- failed execution count:
- selected failed job exists: yes / no

## Operation Target

保存してよい項目だけを記録する。

- failed_job_id:
- job_id:
- queue_name:
- class_name:
- active_job_id:
- failed_at:
- retryable:
- discardable:
- selected action: retry / discard / observation-only
- reason_template:
- operator_actor_id:
- project_id:

## Approval

- release owner approval:
- incident commander approval:
- project admin/owner confirmed:
- side-effect risk reviewed:
- production operation allowed: yes / no / not-applicable

## Operation Result

- request path:
- response status:
- response code:
- operated_at:
- safe response fields only: yes / no
- raw exception absent: yes / no
- backtrace absent: yes / no
- serialized job arguments absent: yes / no
- secret/token/database URL absent: yes / no
- DM body or AI prompt absent: yes / no

## AuditLog Result

- AuditLog action: `operations.failed_job_retried` / `operations.failed_job_discarded` / not-executed
- AuditLog created_at:
- operator_actor_id:
- reason_template:
- metadata contains failed_job_id:
- metadata contains queue_name/class_name:
- metadata contains raw exception/backtrace/job arguments: no
- metadata contains secrets/tokens/database URLs: no

## Queue Health After

- checked_at:
- status:
- failed execution count:
- selected failed job still actionable: yes / no
- worker count:
- stale worker count:
- new warnings:

## 良かった点

-

## 改善点

-

## 優先順位

- P1:
- P2:

## 次アクション

1.

## 結論

- [ ] pass
- [ ] fail
- [ ] blocked

理由:

## Secret Handling Confirmation

- [ ] raw exception was not saved
- [ ] backtrace was not saved
- [ ] serialized job arguments were not saved
- [ ] token or API key was not saved
- [ ] database URL was not saved
- [ ] DM body was not saved
- [ ] AI prompt or model output was not saved
