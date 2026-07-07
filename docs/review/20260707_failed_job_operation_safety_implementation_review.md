# 2026-07-07 failed job操作安全制御 実装レビュー

## 評価日時

2026-07-07 16:55 JST

## 評価担当

Codex一次レビュー

- Security Engineer
- Backend Architect
- Frontend Architect
- QA
- Product Manager

## Issue番号

ISSUE-061 / GitHub Issue #90

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- HEART
- ISO25010

## 対象

failed job retry/discard操作のaction別理由テンプレート、discard確認、Queue health運用履歴、SLO候補。

## 実装内容

- OpenAPIでretry/discard request schemaを分離した。
- Backendでretry理由とdiscard理由をaction別にvalidationするようにした。
- discardは `discard_safety_confirmed: true` がない場合に拒否するようにした。
- Queue health responseへ24時間のretry/discard/rejected件数とsafe操作履歴を追加した。
- Frontendで再実行理由、破棄理由、破棄リスク確認チェックを分離した。
- Queue health panelに操作件数と失敗ジョブ操作履歴を表示した。
- Queue health responseの古いモックや旧レスポンスで `failed_job_operation_metrics` / `failed_job_operation_history` が欠落しても、Frontend側で安全な既定値へ正規化するようにした。
- SLO候補を `docs/evaluation/20260707_failed_job_operation_slo_candidates.md` に保存した。

## Rails責務分離方針

- Controller: request parameter受け取りとService呼び出しに限定。
- Service Object: `Operations::FailedJobOperationService` がaction別validation、discard確認、retry/discard実行、AuditLog保存を担当。
- Query Object: `Operations::QueueHealthQuery` がAuditLog由来のsafe metrics/historyを返す。
- 過剰設計回避: Slack通知、外部監視、二人承認はISSUE-063 / GitHub Issue #96へ分離し、明示マッピングはISSUE-062 / GitHub Issue #94へ分離した。ISSUE-061では安全制御MVPに限定。

## G-STACK

- Goal: failed job操作の誤操作、説明不足、検知遅れを減らす。
- Strategy: action別理由、discard確認、safe運用履歴、24時間メトリクスを追加する。
- Tactics: OpenAPI、Backend、Frontend、RSpec、Playwright、SLO文書を同期した。
- Assessment: MVPの安全性は改善した。ただし通知と二人承認は未実装であり、本番高リスク操作では追加が必要。
- Conclusion: PR CI成功後にIssue #90はクローズ可能。
- Knowledge: destructive operationはUI確認だけでなくAPI側の必須parameterで止める必要がある。

## STRIDE / OWASP確認

| 観点 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 維持 | project admin認可とactor_id監査を継続 |
| Tampering | 改善 | discard確認をAPI側必須にした |
| Repudiation | 改善 | 操作履歴をAuditLog由来でQueue healthへ表示 |
| Information Disclosure | 維持 | raw exception、backtrace、secret、free-form理由を返さない |
| Denial of Service | 要継続 | 通知と自動抑制は未実装 |
| Elevation of Privilege | 維持 | Project境界検証はISSUE-059の実装を継続使用 |
| OWASP A01 Broken Access Control | 維持 | Project roleと境界検証を維持 |
| OWASP A09 Logging/Monitoring | 改善 | retry/discard/rejected件数と履歴を追加 |

## 良かった点

- retryとdiscardの理由テンプレートを分離し、action不一致をAPIで拒否できる。
- discard操作に明示確認を必須化し、UIだけでなくBackendでも検証できる。
- Queue health画面で24時間の操作件数と直近操作履歴を確認できる。
- free-form理由を増やさず、秘密情報混入リスクを抑えた。
- CIの全E2Eで見つかった旧queue-health payload互換性の欠落を修正し、運用画面の耐障害性を上げた。
- RSpecとPlaywrightで安全制御を確認した。

## 改善点

- Slack通知や外部監視通知はISSUE-063 / GitHub Issue #96で継続する。
- 二人承認はISSUE-063 / GitHub Issue #96で継続する。
- retry後再失敗率はISSUE-062の明示マッピング後でないと正確に出せない。
- 操作履歴はQueue health内の直近表示であり、検索可能な専用履歴UIではない。
- Frontend互換正規化はUIクラッシュ回避を目的とした防御であり、API契約の必須項目を緩めるものではない。

## 改善案

- ISSUE-063 / GitHub Issue #96で高リスクdiscardを二人承認またはowner承認に引き上げる。
- ISSUE-063 / GitHub Issue #96でSlack通知または外部監視SaaS通知をrelease gate前に設計する。
- AuditLog viewerにfailed job操作filterを追加する。
- ISSUE-062完了後、retry後再失敗率をQueue health metricsへ追加する。

## 優先順位

| 優先度 | 項目 | 状態 |
| --- | --- | --- |
| P0 | action別理由テンプレート | 完了 |
| P0 | discard確認必須 | 完了 |
| P1 | safe運用履歴 | 完了 |
| P1 | SLO候補定義 | 完了 |
| P2 | Slack通知、外部監視、二人承認 | ISSUE-063 / GitHub Issue #96で継続 |

## 検証結果

- `git diff --check`: 成功
- `git diff --cached --check`: 成功
- `bundle exec rspec spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 18 examples, 0 failures
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed
- 2026-07-07 18:47 JST追記: PR #97 CIの全E2Eで、旧queue-health mockに新規履歴項目がなく画面が落ちる不備を検出。Frontendでqueue-health payloadを正規化し、関連E2Eでは該当クラッシュが解消した。ローカルの `npm run frontend:e2e -- e2e/auth-session.spec.ts e2e/meeting-workspace.spec.ts e2e/queue-health.spec.ts` は20 passed、6 failed。失敗6件はローカルRails API未起動による `127.0.0.1:3001` 接続不可であり、今回の互換修正とは別要因。
- 2026-07-07 18:51 JST追記: PR #97 GitHub Actions `verify` run 28857189655 / job 85586547052 は成功。CheckRun annotationsは空。

## 次アクション

1. GitHub Issue #90へ検証結果をコメントし、PR #97 mergeでクローズする。
2. Slack通知、二人承認、再失敗率はISSUE-063 / GitHub Issue #96で継続する。
