# Requirement承認ブロッカー表示 設計レビュー

## 評価日時

2026-07-07 06:31 JST

## 評価担当

Codexレビュー統括 / Product Manager / Frontend Architect / Backend Architect / Security Engineer / QA / UI/UX Designer

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- MoSCoW

## 対象

Issue #3のRequirement Workspaceに、未解決レビュー件数と承認ブロッカー詳細を表示する改善を設計する。

## 良かった点

- Backendの `GET /reviews?target_type=requirement&target_id=...` が既にあり、追加APIなしでRequirement対象Reviewを取得できる。
- `RequirementApprovalGate` は未決事項、未解決レビュー、期限切れ `accepted_risk` を既に判定しているため、UI表示は同じ条件を薄く反映すればよい。
- 既存の `validation-panel` と `audit-box` のUI部品を使えるため、画面全体の視覚体系を崩さずに追加できる。
- 承認ボタンの近くにブロッカーを出すことで、ユーザーがAPIエラーを受けて初めて理由を知る体験を減らせる。

## 改善点

- UI側判定は補助表示であり、最終判定はBackend gateに依存する必要がある。
- `accepted_risk` の期限判定はクライアント時刻に依存するため、厳密なgateとしては扱わない。
- Review履歴の全差分や解決理由の詳細表示までは今回の範囲に含めない。
- `lastReview` はMinutesとRequirementで兼用されており、Requirement専用の一覧stateを分けた方が誤表示を避けやすい。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | 未解決レビュー件数が見えない | Requirement専用reviews stateを追加し、open/action_required件数を表示する |
| P0 | 承認ブロッカー理由がAPI実行後まで見えない | 未決事項、未解決レビュー、期限切れリスク受容をパネル表示する |
| P1 | レビュー状態が1件表示中心 | 最新レビューだけでなく一覧からブロッカー候補を最大数件表示する |
| P2 | `accepted_risk` 期限の厳密性 | UIは補助表示に留め、Backend gateを最終判定にする |

## 次アクション

1. `requirementReviews` stateと `loadRequirementReviews` を追加する。
2. Requirement生成、保存、承認、レビュー依頼、レビュー解決後にRequirement reviewsを再読込する。
3. Requirement Workspaceに承認ブロッカーパネルを追加する。
4. Playwrightで未解決件数、ブロッカー表示、解決後の表示変化を確認する。
5. 実装レビューを保存し、Issue台帳へ同期する。

## Issue番号

- GitHub Issue: #3

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Requirement承認前に、なぜ次工程へ進めないかをユーザーが画面上で把握できるようにする |
| Strategy | 既存Reviews APIを利用し、Backend gateと同じブロッカーをFrontendで補助表示する |
| Tactics | Requirement reviews一覧、未決事項件数、未解決レビュー件数、期限切れリスク受容表示、E2E |
| Assessment | 実装へ進めてよい。Backend gateは維持し、UIは説明責務に集中する |
| Conclusion | 追加APIなしのFrontend中心改善として妥当 |
| Knowledge | ReviewOpsの価値は、止めることだけでなく、止まった理由をすぐ理解できることにある |

## 判定

実装へ進めてよい。今回の完了条件は、Requirement専用レビュー一覧、未解決件数、承認ブロッカー詳細表示、E2E、レビュー保存、Issue台帳更新までとする。
