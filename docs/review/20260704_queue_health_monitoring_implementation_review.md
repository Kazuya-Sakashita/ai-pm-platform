# Queue Health Monitoring Implementation Review

## 評価日時

2026-07-04 21:38 JST

## 評価担当

Codex / CTO / Tech Lead / Backend Architect / Frontend Architect / DevOps / Security Engineer / QA / UI/UX Designer / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- DORA Metrics
- ISO25010
- STRIDE
- OWASP Top 10
- WCAG

## Issue番号

- ISSUE-025
- GitHub Issue #25
- 関連: ISSUE-004 / ISSUE-023

## 良かった点

- `GET /api/v1/operations/queue-health` をOpenAPI contractに追加し、Frontend型生成まで同期した。
- Backendは `Operations::QueueHealthQuery` にSolid Queue集計を分離し、Controllerを薄く保った。
- Solid Queue table未準備またはqueue DB接続不可でもAPIが500にならず、`status=unavailable` とsafe warningを返すようにした。
- worker heartbeat、queue unfinished count、oldest unfinished age、failed execution count、recurring task、Product jobs summaryをread-onlyで返せるようにした。
- raw job arguments、raw exception/backtrace、DB URL、state digestなどをresponseに含めないrequest specと、Solid Queue正常系を確認するservice specを追加した。
- Frontendに「運用監視」パネルを追加し、health status、worker/stale数、failed数、queue latency、warning、手動更新を表示できるようにした。
- Playwright E2Eでdegradedからhealthyへの手動更新表示、secret/backtrace非表示を確認した。
- 既存のmock GitHub reconciliation E2Eにqueue health mockを追加し、自動取得によるテスト不安定化を避けた。

## 改善点

- 実staging/productionのSolid Queue tableでhealthy/degradedを確認するlive smokeは未実施。
- failed jobの再実行/破棄、承認者、監査ログ、権限管理は未実装。
- queue latencyやworker heartbeatの通知、SLO、外部監視SaaS連携は未実装。
- thresholdは固定値で、環境別設定やrelease SLOとまだ連動していない。
- Frontendは手動更新のみで、自動pollingや最終成功/失敗履歴はない。
- 認証/認可未実装のため、operations APIの閲覧権限はISSUE-006で制御が必要。

## 優先順位

- P0: CIでBackend spec、OpenAPI verify、Frontend build、queue health E2Eを通す。
- P1: staging/production worker smoke runbookに沿って実環境証跡を保存する。
- P1: failed job再実行/破棄の権限、承認ログ、AuditLog連携を別Issue化する。
- P1: queue latency、failed count、heartbeatの通知設計を追加する。
- P2: thresholdを環境別設定へ移し、SLOとrelease gateへ接続する。

## 次アクション

- ISSUE-025へ実装結果と検証結果を同期する。
- GitHub Issue #25へコメントする。
- ISSUE-004の残タスクから「queue監視設計/初期UI」を完了扱いにし、実staging/production smokeと操作系UIは残す。
- GitHub Actions CIを確認し、成功後もISSUE-025は実環境smoke/操作系が残るため必要に応じてopen維持する。

## G-STACK

### Goal

background job運用状態をアプリ内で安全に把握し、GitHub連携復旧やAI生成jobの運用リスクを下げる。

### Strategy

まずread-onlyのhealth summaryに限定し、危険な操作系は認証/承認ログ設計後へ延期する。

### Tactics

- OpenAPIへQueueHealth schemaを追加する。
- Solid Queue集計をQuery Objectへ分離する。
- 未準備環境を `unavailable` とsafe warningで扱う。
- Frontend左レールに運用監視パネルを追加する。
- Request specとmock E2Eで安全性と表示を固定する。

### Assessment

ISSUE-025のMVPとしては実装完了。世界レベルSaaS基準では、実環境証跡、外部監視、通知、権限、操作監査が残るため、運用完成ではなく「監視の初期可視化」と評価する。

### Conclusion

実装は採用可能。Issue #4のqueue監視残タスクは前進したが、staging/production worker smoke、failed job操作UI、通知/SLOは継続課題である。

### Knowledge

Solid Queueのテーブルは運用情報を多く持つが、argumentsやerror detailをそのまま出すと情報漏えいにつながる。MVPでは集計値とsafe warningだけを返す設計が妥当である。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | 認証未実装のため閲覧者制限は未完 | ISSUE-006でoperator権限を導入 |
| Tampering | read-only APIでqueue状態を変更しない | 操作系は別Issueで承認必須 |
| Repudiation | 閲覧のみでAuditLogは未接続 | retry/discard導入時にAuditLogへ保存 |
| Information Disclosure | raw args、exception、DB URL、state digestを返さないspecを追加 | response serializerの項目固定を維持 |
| Denial of Service | 集計queryはcount/min/max中心 | 大量queue環境ではcache/limitを追加 |
| Elevation of Privilege | 再実行/破棄を未実装にした | operator role導入まで操作UIは禁止 |

## WCAG / UX確認

- statusはchipの色だけでなく「正常」「要確認」「利用不可」の文言で表示する。
- 手動更新ボタンはbutton要素でキーボード操作できる。
- warningはテキストとして表示し、色だけに依存しない。
- 狭幅でのスクリーンショット確認とスクリーンリーダー実機確認は未実施。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/operations_spec.rb spec/services/operations/queue_health_query_spec.rb`: 3 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK（Node engine warning: current v22.7.0）
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/queue-health.spec.ts`: 1 passed
- `git diff --check`: pass

## Issue番号

- ISSUE-025
- GitHub Issue #25
