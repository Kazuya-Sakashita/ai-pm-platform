# Solid Queue Staging Worker Smoke Runbook Review

## 評価日時

2026-07-04 17:42 JST

## 評価担当

Codex / CTO / Tech Lead / DevOps / Backend Architect / Security Engineer / QA / Product Manager

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- DORA Metrics
- ISO25010
- STRIDE
- OWASP Top 10

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 良かった点

- GitHub App credential不要で進められる `staging/production worker smoke` の実行手順を `docs/release/20260704_solid_queue_staging_worker_smoke_runbook.md` に分離した。
- worker起動、heartbeat、recurring task、cleanup job、failed job、queue latencyの確認観点を分けた。
- `QUEUE_DATABASE_URL` の存在確認は必須にしつつ、実値を証跡へ保存しない方針を明記した。
- stagingでは制御された `github_connection_states` の古いstate/active stateを作り、cleanup jobの実行結果を確認できる手順にした。
- productionではデータ作成を原則禁止し、heartbeat、recurring task、failed count、queue latency、次回cleanup観測を中心にする安全策を置いた。
- 証跡保存項目を定義し、後続の `docs/review/YYYYMMDD_solid_queue_worker_smoke_review.md` へそのまま転記できるようにした。

## 改善点

- 実staging環境でのworker heartbeatとrecurring executionはまだ未実施。
- Production smokeは観測中心にしたため、実削除が正しく発火する証明はstagingで先に取る必要がある。
- Solid Queueのfailed job詳細を運用UIで見る画面は未実装。
- Queue latencyやfailed countの継続監視、通知、SLOは未定義。
- cleanup jobの削除件数はRails log中心で、Product用 `jobs` tableやAuditLogにはまだ記録していない。

## 優先順位

- P0: runbookをIssue #4へ同期し、staging worker smokeの実行準備を完了扱いにする。
- P0: 実staging環境でworker heartbeatとrecurring task loadを確認する。
- P1: stagingで制御データを使ってcleanup job実行を確認する。
- P1: productionでは観測only smokeを行い、次回cleanup実行ログとfailed countを保存する。
- P1: queue latency / failed job count / worker heartbeatの監視設計をIssue化する。
- P2: cleanup job実行結果をAuditLogまたは運用メトリクスへ接続する。

## 次アクション

- Issue #4へrunbook追加を同期する。
- 実staging環境が用意できたら、runbookに沿って `docs/review/YYYYMMDD_solid_queue_worker_smoke_review.md` を作成する。
- GitHub App live smokeは、GitHub App設定とcallback到達URLが準備できるまで後回しにする。

## G-STACK

### Goal

Solid Queue workerがstaging/production相当環境で安全に起動し、recurring cleanup jobを実行または観測できる状態にする。

### Strategy

実環境に依存する作業を、事前準備、staging実行、production観測に分解し、秘密情報や削除系操作のリスクを抑える。

### Tactics

- worker heartbeat確認SQLを定義する。
- recurring task確認SQLを定義する。
- staging限定のcleanup実行smokeを定義する。
- productionは観測onlyを原則にする。
- 証跡保存項目と禁止情報を明文化する。

### Assessment

運用準備としては前進した。世界レベルSaaS基準では、手順書だけでは完了ではなく、stagingでの実行証跡、production観測、継続監視、failed job運用UIまで必要である。

### Conclusion

staging/production worker smokeの手順整備は完了。Issue #4の残タスクは「実staging/productionでの実行証跡取得」と「queue監視設計」に絞られた。

### Knowledge

cleanup jobは削除系の定期処理であるため、productionでテストデータを作って削除確認するより、stagingで実削除を証明し、productionではheartbeatとscheduled executionの観測を優先する方が安全である。

## STRIDE / OWASP確認

| 観点 | 評価 | 改善案 |
| --- | --- | --- |
| Spoofing | worker processとqueue DBの接続先確認が必要 | deploy環境でprocess identityを記録 |
| Tampering | smoke用データ作成はstaging限定 | productionは観測onlyを原則にする |
| Repudiation | 証跡テンプレートで誰がいつ確認したか残せる | 実行者IDとレビュー承認者を追加 |
| Information Disclosure | DB URL、raw state、nonce digestの保存禁止を明記 | 証跡スクリーンショットのredaction手順を追加 |
| Denial of Service | worker停止やqueue詰まり検知を含めた | queue latency監視を実装 |
| Elevation of Privilege | production操作はrelease owner承認前提 | 認証/権限設計後に運用者権限を制御 |

## DORA / 運用確認

- Deployment frequency: worker processをweb processと独立して検証する必要がある。
- Lead time for changes: runbook化により、staging smokeの準備時間を短縮できる。
- Change failure rate: queue misconfigurationと`QUEUE_DATABASE_URL`漏れをrelease前に検出できる。
- MTTR: heartbeat、failed count、latency snapshotにより初動調査が速くなる。

## 検証結果

- `git diff --check`: pass

## Issue番号

- ISSUE-004
- GitHub Issue #4
