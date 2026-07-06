# 2026-07-06 Requirement承認Review Center連携レビュー

## 評価日時

2026-07-06 20:52:04 JST

## 評価担当

Codex as Tech Lead / Backend Architect / QA / Security Engineer / Product Manager

## Issue番号

GitHub Issue #3

## 対象成果物

- `backend/app/services/requirement_approval_gate.rb`
- `backend/app/controllers/api/v1/requirements_controller.rb`
- `backend/spec/services/requirement_approval_gate_spec.rb`
- `backend/spec/requests/api/v1/requirements_spec.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`

## 使用フレームワーク

- G-STACK
- ISO25010
- DDD
- STRIDE
- MoSCoW

## 評価サマリー

Requirement承認条件を、従来の `open_questions` の有無だけでなく、Review Centerの未解決レビュー状態へ接続した。対象Requirementに `open` または `action_required` のレビューが残っている場合、`POST /requirements/{id}/approve` は409 `review_required` を返し、次工程であるIssue/OpenAPI生成へ進めない。

これにより、AGENTS.mdの「レビューなしで次工程へ進まない」ルールがRequirement承認ゲートに反映された。

## G-STACK評価

### Goal

未解決レビューが残るRequirementを承認できないようにし、Issue生成とOpenAPI設計へ流れる前にレビュー指摘を必ず解決する。

### Strategy

Controllerへ条件を直接詰め込まず、`RequirementApprovalGate` を追加して承認可否を判定する。Controllerは認可、gate呼び出し、レスポンス返却に集中させる。

### Tactics

- `open_questions` が残る場合は従来どおり承認不可にした。
- `target_type=requirement` かつ `status=open/action_required` のReviewを承認blockerにした。
- `resolved` と `accepted_risk` は次工程へ進める状態として扱った。
- request specとservice specで承認blockerを確認した。
- FrontendのRequirement Workspaceに `要件レビュー対応済み` 導線を追加し、E2Eのhappy pathも未解決Reviewを解決してから承認する流れに更新した。

### Assessment

関連RSpec 48 examples、Frontend build、日本語表示チェックが成功し、Issue/OpenAPI生成前のRequirement承認ゲートは強化された。一方で、accepted_riskの期限切れや承認者メタデータはまだ承認条件に入っていない。

### Conclusion

今回のReview Center連携は合格。ただし、AI PMとして世界レベルの監査性を目指すには、risk acceptanceの期限管理とRequirement承認者情報の永続化が次の改善対象である。

### Knowledge

Requirement承認は単なるステータス変更ではなく、後続Issue/OpenAPI生成の安全弁である。未解決レビューを承認ゲートへ接続することで、レビュー記録が実際のワークフロー制御に使われる。

## 良かった点

- Review Centerの `open/action_required` がRequirement承認を止めるようになった。
- `resolved/accepted_risk` を許可し、現実的なリスク受容フローを残した。
- Controller責務を肥大化させず、承認判定をService Objectへ分離した。
- request specとservice specの両方で回帰を防いだ。
- Issue/OpenAPI生成ゲートの前段で止めるため、後続工程への不良流出を減らせる。
- Frontendにも最小限のレビュー解決導線を追加し、ユーザーがRequirement承認前にReview Center状態を更新できるようになった。

## 改善点

- `accepted_risk.expires_at` の期限切れを承認blockerとして扱っていない。
- Requirement承認時の承認者、承認日時、承認コメントがRequirement本体には残らない。
- 未解決Reviewの件数、重要度、詳細リンクをFrontendの承認ボタン近くで強調するUXはまだ弱い。
- Review blockerの詳細はAPI error detailsには出るが、OpenAPI schema上の詳細型はまだ厳密化していない。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | Requirement承認者、承認日時、承認コメントを保存する | 監査性と責任境界に直結する |
| P0 | accepted_riskの期限切れを承認blockerにする | 期限切れリスク受容で次工程へ進む事故を防ぐ |
| P1 | Frontendで未解決Review件数と詳細リンクを承認導線に表示する | UXとレビュー効率を上げる |
| P1 | OpenAPI error detailsを厳密化する | API利用者がblockerを機械的に扱いやすくなる |

## 次アクション

- Requirement承認メタデータをDB/APIへ追加するIssueを切る、またはIssue #3の残タスクとして実装する。
- `accepted_risk.expires_at` を評価するReview blockerを追加する。
- Frontend Requirement Workspaceで未解決レビュー件数、重要度、詳細リンクを表示する。

## 判定

合格。

Review CenterとRequirement承認条件の接続は完了。ただし、監査メタデータと期限切れrisk acceptanceの扱いは未完了であり、Issue #3は継続する。
