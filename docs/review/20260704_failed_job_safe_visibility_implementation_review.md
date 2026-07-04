# Failed Job Safe Visibility Implementation Review

## 評価日時

2026-07-04 21:18 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Frontend Architect / DevOps / Security Engineer / QA / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## Issue番号

- ISSUE-027
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/27

## 良かった点

- OpenAPIを先に更新し、`failed_job_samples` をFrontend生成型まで同期した。
- Backendは `SolidQueue::FailedExecution#error` やjob argumentsを読まず、queue/class/active_job_id/failed_atだけを返す実装にした。
- Solid Queue table未準備時も `failed_job_samples: []` を返し、Frontendが同じcontractを扱える。
- Frontend運用監視パネルに「直近失敗ジョブ」を追加し、queue/class/failed_atをread-onlyで確認できる。
- retry/discard/pause/unpauseなど破壊的操作を入れず、operator権限とAuditLog設計前の危険な操作を避けた。
- Playwrightで狭い左カラムに長いjob class名が隠れる問題を検出し、縦積みレイアウトへ修正した。

## 改善点

- failed jobの原因分類、runbookリンク、対応者アサインは未実装。
- failed job retry/discardは、認証、operator role、承認者、理由テンプレート、AuditLogが未整備のため未実装。
- 実staging/productionのSolid Queue failed executionを使ったsmoke証跡は未取得。
- 通知、SLO、外部監視連携、閾値の環境別設定は未設計。
- `active_job_id` は相関IDとして返しているが、認証導入後に閲覧権限と保持方針を再評価する必要がある。

## 優先順位

- P0: raw exception、backtrace、job arguments、DB URL、token、state digestを返さない状態を維持する。
- P0: read-only運用監視の範囲に留め、操作系をこのIssueへ混ぜない。
- P1: 実staging/production worker smokeでfailed job sample表示の証跡を取得する。
- P1: operator権限、承認ログ、AuditLogつきretry/discardを別Issueで設計する。
- P1: queue failed count、latency、worker heartbeatの通知/SLOを設計する。

## 次アクション

- CI成功後にGitHub Issue #27へ結果をコメントし、クローズする。
- ISSUE-004、ISSUE-023、ISSUE-025の残タスクから「failed job safe visibility」を完了扱いへ更新する。
- retry/discard操作は認証/監査設計後の別Issueとして扱う。
- 実staging/production worker smoke証跡を `docs/review/` へ保存する。

## 検証結果

- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `bundle exec rspec spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 3 examples, 0 failures
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed

## G-STACK

### Goal

運用者がfailed jobの発生箇所を安全に把握できるようにし、runbook確認前の初動を速くする。

### Strategy

Queue health APIを拡張し、secret-bearing payloadや操作系を除いたsafe summaryだけを返す。

### Tactics

- `FailedJobSample` schemaを追加する。
- `Operations::QueueHealthQuery` でfailed executionとjob metadataをsafe fieldsへ変換する。
- raw error/argumentsを読まないことをRSpecで固定する。
- Frontendで直近3件だけをコンパクトに表示する。

### Assessment

MVPの安全な可視化としては妥当。ただし世界レベルSaaS基準では、権限、監査つき操作、通知、実環境証跡、SLOがまだ不足している。

### Conclusion

ISSUE-027の実装は完了可能。ただし、retry/discardは別Issueで権限とAuditLogを先に設計すること。

### Knowledge

Solid Queueのfailed executionはraw exceptionやjob argumentsを含み得る。AI PM Platformでは、運用初動に必要なqueue/class/時刻と、秘密情報を含む詳細原因を明確に分離する必要がある。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 認証未実装のため閲覧者制御は未完 | ISSUE-006でoperator roleを導入 |
| Tampering | read-onlyでqueue状態を変更しない | retry/discardは別Issue |
| Repudiation | 閲覧のみのためAuditLogなし | 操作導入時に承認者、理由、対象job、結果をAuditLog化 |
| Information Disclosure | raw error/argumentsを返さない実装とspecを追加 | active_job_idの閲覧権限を認証導入時に再評価 |
| Denial of Service | 直近5件にlimitし、Frontendは3件だけ表示 | 将来はcacheと環境別limitを設定 |
| Elevation of Privilege | 操作UIを追加していない | operator権限まで操作UI禁止 |
