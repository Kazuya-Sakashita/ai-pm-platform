# 2026-07-07 failed job再実行/破棄operator操作 設計レビュー

## 評価日時

2026-07-07 12:35:00 JST

## 評価担当

Codex（DevOps / Security Engineer / Backend Architect / Frontend Architect / QA）

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## 対象Issue

- ISSUE-056
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/81
- 親Issue: ISSUE-004 / GitHub Issue #4

## 対象成果物

- `docs/issue/ISSUE-056_failed_job_retry_discard_operations.md`
- `docs/api/openapi.yaml`
- `backend/app/controllers/api/v1/operations_controller.rb`
- `backend/app/services/operations/failed_job_operation_service.rb`
- `frontend/app/workspace-client.tsx`

## 評価概要

Queue health監視MVPではfailed jobをsafe summaryとして表示できるようになったが、再実行/破棄は未実装である。運用復旧を進めるには操作API/UIが必要だが、failed job操作は誤操作、権限逸脱、秘密情報露出、証跡不足のリスクが高い。したがって、最小MVPでは単体操作、project admin限定、理由テンプレート必須、AuditLog必須、raw exception非表示に限定する。

## G-STACK

- Goal: failed job発生時に、運用者が安全に再実行または破棄できる。
- Strategy: 既存のQueue health panelを拡張し、操作APIはOpenAPI駆動でadmin専用にする。
- Tactics: failed job sampleへ `failed_job_id` と `operations` を追加し、`POST /operations/failed-jobs/{failed_job_id}/retry` と `POST /operations/failed-jobs/{failed_job_id}/discard` を追加する。
- Assessment: 操作系は可用性に寄与するが、破棄は不可逆に近いため理由テンプレートとAuditLogなしでは不合格。
- Conclusion: 設計は条件付きで妥当。raw exception、job arguments、DB URL、tokenをAPI/UI/AuditLogへ出さないことを必須条件にする。
- Knowledge: 今後のbulk操作、通知、SLO、staging/production smokeは別Issueへ分離する。

## STRIDE / OWASP観点

- Spoofing: `current_actor_id` とproject membership admin確認を必須にする。
- Tampering: `failed_job_id` はSolid Queue failed executionから取得し、client supplied class/queueを信用しない。
- Repudiation: `operations.failed_job_retried` / `operations.failed_job_discarded` AuditLogを保存する。
- Information Disclosure: raw error、backtrace、job arguments、serialized argumentsは返却、表示、監査保存しない。
- Denial of Service: bulk操作は非スコープ。単体操作のみで初期リスクを抑える。
- Elevation of Privilege: viewer/editor/reviewerは403とし、admin/ownerのみ許可する。

## 良かった点

- 既存のQueue health API/UIを土台にでき、運用者の導線が増えすぎない。
- Solid Queueの `FailedExecution#retry` / `#discard` を使えるため、独自queue操作を再実装しない。
- Project admin限定と理由テンプレート必須により、操作ログの説明責任を残せる。
- raw exceptionを扱わない既存方針を維持できる。

## 改善点

- failed jobがどのProjectに属するかをSolid Queue job単体から厳密に復元できない場合がある。
- 操作対象が本当に当該Project由来のjobかをMVPでは完全保証しにくい。
- discardはjob自体を削除するため、操作後に再調査できる情報が減る。
- staging/production worker smokeなしでは、実worker下でのretry/discardの挙動証跡が不足する。

## 改善案

- MVPではQueue health取得時と同じproject admin権限を必須にし、操作ログへproject_id、failed_job_id、job_id、queue_name、class_name、operator_actor_id、reason_templateだけを保存する。
- 将来、Product `jobs` とSolid Queue jobの関連IDを明示保存し、Project境界をより厳密にする。
- discardには「既に手動対応済み」「再実行不要」「危険な副作用を避ける」のテンプレートを用意し、free-form noteは初期MVPでは保存しない。
- staging/production worker smoke runbookへretry/discard実行証跡項目を追記する。

## 優先順位

- P0: admin限定、理由テンプレート必須、AuditLog保存、raw exception非露出。
- P1: Frontendから再実行/破棄後にQueue healthを再取得する。
- P1: RSpecでviewer拒否、存在しないfailed job、操作成功を確認する。
- P2: Playwrightで操作導線と日本語表示を確認する。
- P2: bulk操作、通知、SLO、staging/production smokeを別Issue化する。

## 次アクション

1. OpenAPI contractを追加する。
2. `Operations::FailedJobOperationService` を追加する。
3. `OperationsController` へretry/discard actionを追加する。
4. Queue health panelへ操作ボタンと理由テンプレート選択を追加する。
5. RSpec、Playwright、`api:verify`、`display:check`、`frontend:build` を実行する。

## Issue番号

- ISSUE-056
- GitHub Issue #81
- 親Issue: GitHub Issue #4

## 判定

条件付き合格。操作系は世界レベルSaaSの運用品質に必要だが、権限、理由、監査、安全な情報境界を満たさない実装は不合格とする。
