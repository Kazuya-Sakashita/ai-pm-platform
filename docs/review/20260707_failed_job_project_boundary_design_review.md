# 2026-07-07 failed job Project境界厳密化 設計レビュー

## 評価日時

2026-07-07 16:03:58 JST

## 評価担当

Codex（Security Engineer / Backend Architect / Tech Lead / QA / DevOps）

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DDD

## 対象Issue

- ISSUE-059
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/88
- 親Issue: ISSUE-004 / GitHub Issue #4

## 対象成果物

- `docs/issue/ISSUE-059_failed_job_project_boundary_hardening.md`
- `docs/api/openapi.yaml`
- `backend/app/services/operations/failed_job_project_resolver.rb`
- `backend/app/services/operations/failed_job_operation_service.rb`
- `backend/app/services/operations/queue_health_query.rb`
- `frontend/app/workspace-client.tsx`

## 評価概要

ISSUE-056で追加したfailed job再実行/破棄MVPは、project admin権限とQueue health画面文脈を前提にしていた。しかし本番SaaSの運用操作では、別Project由来のfailed jobを誤操作しないため、サーバー側でProduct JobとSolid Queue jobの関連を検証する必要がある。

今回の設計では、Solid Queue job argumentsからProduct `Job` ID候補を抽出し、単一のProduct Jobに解決でき、かつ要求Projectと一致する場合のみ操作可能にする。未解決、複数候補、DB参照失敗、Project不一致はsafe 404で拒否し、AuditLogへ安全な境界検証結果を残す。

## Rails責務分離方針

- Controller: project必須、project admin認可、入力受け取り、Result返却に限定する。
- Query Object: `Operations::QueueHealthQuery` がProject文脈つきのfailed job sample抽出を担当する。
- Service Object: `Operations::FailedJobOperationService` がretry/discard実行とAuditLog保存を担当する。
- Resolver Object: `Operations::FailedJobProjectResolver` がSolid Queue jobからProduct Job境界を復元する。
- 過剰設計回避: 新規DBテーブルや永続マッピングは導入せず、既存のActiveJob引数に含まれるProduct Job IDを検証する最小強化に限定する。

## G-STACK

- Goal: failed job操作対象が要求Project由来であることをAPI側で保証する。
- Strategy: UI文脈ではなく、Solid Queue job argumentsからProduct Jobを復元し、Project一致を必須条件にする。
- Tactics: Resolverを追加し、Queue health sampleとretry/discard操作の両方で同じ境界判定を使う。
- Assessment: MVPの安全性は大きく上がる。ただしActiveJob引数形式に依存するため、将来は明示的な関連ID保存を検討すべきである。
- Conclusion: 設計は条件付き合格。Project不一致時に他ProjectのIDを返却、表示、監査ログへ露出しないことを必須条件にする。
- Knowledge: 運用操作では「操作できること」より「間違った対象を操作できないこと」を優先する。

## STRIDE / OWASP観点

- Spoofing: client supplied project_idだけを信用せず、server側でProduct JobのProjectを確認する。
- Tampering: failed_job_idから取得したSolid Queue jobを基準にし、client supplied class名やqueue名は信用しない。
- Repudiation: 境界拒否時も `operations.failed_job_project_boundary_rejected` としてAuditLogへ保存する。
- Information Disclosure: raw job arguments、例外、backtrace、secret、別ProjectのIDをAPI/UI/AuditLogへ露出しない。
- Denial of Service: lookup件数を制限し、Queue health sampleは最大件数に限定する。
- Elevation of Privilege: Project不一致は存在有無を推測しにくい404として返す。

## 良かった点

- Controllerではなく専用Resolverへ境界復元を分離する設計になっている。
- 操作APIとQueue health sampleで同じ判定を使うため、表示と操作の不一致を減らせる。
- Project不一致、未解決、複数候補、DB参照失敗を明示的な境界ステータスとして扱える。
- OpenAPIへ `project_boundary_status` を追加し、Frontend型と同期できる。
- 境界拒否時もAuditLogに残すため、運用監査で不正操作試行や設定不備を追跡できる。

## 改善点

- ActiveJob arguments内のUUID探索に依存しており、将来job引数形式が変わると境界復元できなくなる。
- Queue healthのProject別failed execution countはsample抽出に基づくため、全件数ではない。
- 複数Product Job IDがargumentsに含まれる場合は安全側で拒否するが、原因調査用の運用ガイドがまだ薄い。
- Project境界検証ステータスはUIに最小表示しているが、AuditLog viewerでの検索導線は未整備である。

## 改善案

- 後続でSolid Queue job IDとProduct Job IDの明示マッピングを保存するADRを検討する。
- Queue health APIに「sample count」と「unverified hidden count」を分離する設計を追加する。
- `project_mismatch` や `product_job_ambiguous` 発生時のrunbookを追加する。
- AuditLog viewerで境界拒否イベントを検索、絞り込みできるようにする。

## 優先順位

- P0: Project不一致failed jobをsafe 404で拒否する。
- P0: 境界拒否AuditLogに他ProjectのID、raw arguments、例外詳細を保存しない。
- P0: OpenAPI、Backend、Frontend型、RSpecを同期する。
- P1: Queue health sampleで境界確認済みの失敗ジョブだけ操作可能にする。
- P2: 明示マッピング保存とAuditLog viewer改善を後続Issue化する。

## 次アクション

1. Resolver、Operation Service、Queue Health Queryを実装する。
2. OpenAPIとFrontend型を同期する。
3. RSpecで成功、Project不一致、未解決、sample非表示を検証する。
4. PlaywrightでQueue health表示と再実行導線を検証する。
5. 実装レビューを保存し、GitHub Issue #88へ同期する。

## Issue番号

- ISSUE-059
- GitHub Issue #88
- 親Issue: GitHub Issue #4

## 判定

条件付き合格。Project境界をサーバー側で確認する設計として妥当だが、明示的な永続マッピングではないため、将来の引数形式変更に備えた後続改善が必要である。
