# Conversation Summary Draft Review Center連動設計レビュー

## 評価日時

2026-07-06 12:06:32 JST

## 評価担当

Codex / Product Manager / Frontend Architect / Backend Architect / QA / Security Engineer / UI/UX Designer

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- STRIDE

## Issue番号

ISSUE-037 / GitHub #37

## 対象

- `docs/issue/ISSUE-037_conversation_summary_review_center_integration.md`
- `docs/api/openapi.yaml`
- `backend/app/models/review.rb`
- `backend/app/controllers/api/v1/reviews_controller.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- OpenAPIの `ReviewTargetType` には `conversation_summary_draft` が既に定義されており、API駆動の方向性は合っている。
- ISSUE-036でDM整理ドラフト編集UIが入り、レビュー前にAI出力を修正できる状態になっている。
- 既存Reviews APIとReview Center UIがあり、議事録/要件レビューのパターンを再利用できる。
- ProjectMembershipによるreview role gateが既に存在し、DM整理ドラフトにも適用できる。

## 改善点

- Backendの `Review::TARGET_TYPES` と `ReviewsController#project_for_review_target` が `conversation_summary_draft` 未対応で、OpenAPIと実装が乖離している。
- DM整理ドラフト承認はReview Center状態を見ずに実行でき、`action_required` / `needs_revision` 相当のブロッカーが効かない。
- Review Centerのゲート表示にDM整理ドラフトのレビュー状態が出ておらず、監査体験が分断されている。
- Review履歴は作成できても、DM整理パネルから対象レビューを読み出す導線がない。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | Backend target mapping不足 | `conversation_summary_draft` をReview対象としてproject境界へ追加する |
| P1 | 承認前ブロッカー不足 | DM整理ドラフト承認前に未解決レビューを確認してブロックする |
| P1 | UIからレビュー依頼できない | DM整理パネルへレビュー依頼ボタンと状態表示を追加する |
| P2 | Review履歴の一覧性 | まず最新レビュー表示、履歴カードは後続改善 |
| P2 | 外部AI複数レビュー未実施 | 現時点ではCodex一次レビューとして記録 |

## 次アクション

1. Backend Review targetに `conversation_summary_draft` を追加し、request specで作成/一覧/project境界を固定する。
2. FrontendでDM整理ドラフトレビューを読み込み、レビュー依頼ボタンとブロッカー表示を追加する。
3. 承認処理で `action_required` / `needs_revision` 相当のレビューをブロックする。
4. Playwrightでレビュー依頼、ブロック、承認可能状態を検証する。
5. 実装レビューを保存する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM整理ドラフトをReview Centerの統制対象へ接続する |
| Strategy | OpenAPIにあるtarget typeへBackend/Frontendを追従し、承認前にレビュー状態を確認する |
| Tactics | Backend target mapping、request spec、DMレビューstate、レビュー依頼ボタン、ブロッカー表示、E2E |
| Assessment | ISSUE-037は実装に進めてよい。外部AIレビュー実行は非スコープ |
| Conclusion | 実装開始 |
| Knowledge | ReviewOps体験ではレビュー作成だけでなく、次工程を止めるブロッカーが価値になる |

## 判定

合格。

ISSUE-037は実装へ進める。ただし、Backend target mapping、承認ブロック、E2E、レビュー保存まで完了してからPR化する。
