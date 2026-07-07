# 2026-07-07 failed job再実行/破棄operator操作 実装レビュー

## 評価日時

2026-07-07 12:52:00 JST

## 評価担当

Codex（DevOps / Security Engineer / Backend Architect / Frontend Architect / QA / Tech Lead）

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

- `docs/api/openapi.yaml`
- `backend/app/controllers/api/v1/operations_controller.rb`
- `backend/app/services/operations/failed_job_operation_service.rb`
- `backend/app/services/operations/queue_health_query.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/queue-health.spec.ts`
- `docs/issue/ISSUE-056_failed_job_retry_discard_operations.md`

## 評価概要

failed jobのsafe visibilityに続き、project adminが単体failed jobを理由テンプレート付きで再実行または破棄できるMVP操作を追加した。OpenAPI、Backend、Frontend型を同期し、Queue health panelから操作後に再取得できる導線を追加している。

操作系は可用性改善に直結する一方、誤操作、権限逸脱、raw exception露出、監査不足のリスクが高い。今回の実装では、Controllerを薄く保ち、Solid Queue操作とAuditLog保存を `Operations::FailedJobOperationService` へ集約した。

## Rails責務分離方針

- Controller: actor必須、project必須、project admin認可、入力受け取り、Resultに応じたレスポンス返却に限定。
- Service Object: failed execution検索、retry/discard実行、AuditLog保存、safe error contractを担当。
- Query Object: `Operations::QueueHealthQuery` がQueue health summaryとfailed job sampleを返す。
- OpenAPI: 操作API、reason template、response schemaを定義し、Frontend型へ同期。
- 過剰設計回避: bulk操作、通知、SLO、Project境界の厳密関連ID保存はMVP外とし、単体操作だけに限定。

## G-STACK

- Goal: failed job発生時に、運用者が安全に復旧操作できる状態を作る。
- Strategy: Queue health panelの既存文脈に操作を統合し、admin限定と理由テンプレートで監査可能にする。
- Tactics: failed job sampleに `failed_job_id` と操作可否を追加し、retry/discard APIとFrontend操作ボタンを追加する。
- Assessment: MVP条件は満たす。ただしstaging/production worker smokeとProject境界の厳密紐付けは後続課題。
- Conclusion: PR CI成功後、Issue #81はクローズ可能。
- Knowledge: failed job操作は便利さよりも、権限、理由、監査、情報非露出を優先する。

## 良かった点

- ControllerにSolid Queue操作を詰め込まず、Service Objectへ分離できている。
- `reason_template` を必須化し、free-form本文をAuditLogへ保存しない設計にした。
- AuditLog metadataにはfailed job ID、job ID、queue名、class名、operator ID、reason templateだけを保存し、raw exceptionやbacktraceを含めていない。
- Queue health panelから操作後に再取得するため、運用者が結果をすぐ確認できる。
- RSpecで成功、権限拒否、safe validation error、AuditLogの秘密情報非混入を確認している。
- Playwrightで失敗ジョブ表示、理由選択、再実行、再取得導線を確認している。

## 改善点

- Solid Queue jobからProject境界を厳密に復元できないため、MVPではProject admin権限と運用画面文脈に依存している。
- discard後は調査可能な情報が減るため、本番運用では二人承認や追加確認を検討すべきである。
- staging/production worker smokeは未実施で、実worker下のretry/discard挙動証跡はまだない。
- bulk操作、通知、SLO、操作失敗時の運用アラートは未実装である。
- 理由テンプレートはMVPとして共通化しており、action別テンプレート制御は将来改善余地がある。

## 改善案

- Product JobとSolid Queue jobの関連IDを明示保存し、Project境界を厳密に検証できるようにする。
- discard操作には確認ダイアログ、二人承認、またはリスクレベル別制御を追加する。
- staging/production worker smoke runbookにfailed job retry/discardの証跡項目を追加する。
- action別の理由テンプレート制御を導入し、retry理由とdiscard理由の誤選択を減らす。
- 操作結果を運用監視履歴またはAuditLog viewerで追跡しやすくする。

## 優先順位

- P0: PR CI `verify` 成功確認。
- P0: GitHub Issue #81へ実装内容と検証結果を同期し、クローズする。
- P1: staging/production worker smoke runbookへretry/discard証跡を追加する。
- P1: Project境界を厳密化する関連ID保存設計を検討する。
- P2: action別理由テンプレート、二人承認、通知、SLOを後続Issue化する。

## 検証結果

- `bundle exec rspec spec/services/operations/failed_job_operation_service_spec.rb spec/services/operations/queue_health_query_spec.rb spec/requests/api/v1/operations_spec.rb`: 12 examples, 0 failures
- `npm run api:verify`: 成功。Redocly CLIのNode version warningのみ非ブロッキング
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "Queue health operations panel"`: 1 passed

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後、GitHub Issue #81へ検証結果をコメントする。
3. GitHub Issue #81をクローズする。
4. staging/production worker smokeはIssue #4またはrelease gateで継続する。

## Issue番号

- ISSUE-056
- GitHub Issue #81
- 親Issue: GitHub Issue #4

## 判定

条件付き合格。MVPとしてのfailed job単体再実行/破棄操作は実装済みであり、PR CI成功後にIssue #81はクローズ可能。staging/production worker smokeとProject境界の厳密化は後続改善として扱う。
