# 2026-07-07 Requirementリスク受容期限ゲートレビュー

## 評価日時

2026-07-07 04:39:18 JST

## 評価担当

Codex as Security Engineer / QA / Tech Lead / Product Manager

## Issue番号

GitHub Issue #3

## 対象成果物

- `backend/app/services/requirement_approval_gate.rb`
- `backend/spec/services/requirement_approval_gate_spec.rb`
- `backend/spec/requests/api/v1/requirements_spec.rb`

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- MoSCoW

## 評価サマリー

Requirement承認ゲートに、Review Centerの `accepted_risk.expires_at` を評価する条件を追加した。期限内のrisk acceptanceは承認可能とし、期限切れ、期限未設定、不正な期限値は409 `review_required` で承認をブロックする。

これにより、期限切れのリスク受容を根拠にRequirementを承認し、Issue/OpenAPI生成へ進めてしまう事故を防げる。

## G-STACK評価

### Goal

期限切れまたは不完全なrisk acceptanceでRequirement承認が進まないようにする。

### Strategy

Review状態を単純な `accepted_risk` 判定で許可せず、`accepted_risk.expires_at` を承認ゲートで評価する。

### Tactics

- `RequirementApprovalGate` で期限切れaccepted_riskをblockerとして扱う。
- `expires_at` が未設定またはparse不能なaccepted_riskもblockerとして扱う。
- API error detailsへ `expired_accepted_risk_review_ids` と `accepted_risk_expires_at` を含める。
- service specとrequest specで期限内、期限切れ、期限なしの挙動を確認した。

### Assessment

関連RSpecは51 examples成功。セキュリティと監査の観点では前進した。一方で、Frontend上で期限切れ理由を承認ボタン付近に明示するUXはまだ弱い。

### Conclusion

合格。期限切れrisk acceptanceをRequirement承認blockerにするP0対応は完了。

### Knowledge

Risk acceptanceは永久許可ではなく、期限、承認者、残余リスク、紐づくIssueが揃って初めて監査可能な例外になる。

## 良かった点

- `accepted_risk` を無条件許可せず、期限を評価するようになった。
- 期限未設定や不正日時を安全側でblockerにした。
- error detailsに期限切れReview IDを含め、FrontendやAPI利用者がblockerを特定しやすくなった。
- RSpecで期限内、期限切れ、期限なしを固定した。

## 改善点

- FrontendのRequirement承認導線で期限切れrisk acceptanceの詳細表示がまだない。
- `accepted_risk.approved_by` や `linked_issue_number` の有効性は承認ゲートで再検証していない。
- Requirement本体には承認者、承認日時、承認コメントがまだ保存されない。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | Requirement承認メタデータをDB/APIへ追加する | 監査証跡の完成度に直結する |
| P1 | Frontendに期限切れrisk acceptanceの詳細を表示する | レビュー担当が修正すべきReviewを判断しやすくなる |
| P1 | linked_issue_numberの存在確認を追加する | 受容リスクが実際に追跡可能か確認できる |

## 次アクション

- Requirement承認者、承認日時、承認コメントを保存する。
- Requirement Workspaceで承認blockerの詳細を表示する。
- OpenAI provider導入時も同じ承認ゲートを経由することを確認する。

## 判定

合格。

期限切れrisk acceptanceの承認blocker化は完了。ただしIssue #3は承認メタデータとOpenAI provider比較が残るため継続する。
