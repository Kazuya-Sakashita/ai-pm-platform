# DM整理ドラフト編集UI設計レビュー

## 評価日時

2026-07-06 11:32:46 JST

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

ISSUE-036 / GitHub #36

## 対象

- `docs/issue/ISSUE-036_discord_dm_summary_draft_edit_ui.md`
- `docs/api/openapi.yaml`
- `backend/app/controllers/api/v1/conversation_summary_drafts_controller.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- `PATCH /conversation-summary-drafts/{conversation_summary_draft_id}` は既にOpenAPIとBackendに存在し、API駆動でFrontendから利用できる。
- Conversation Summary Draftは暗号化payloadへ保存されており、編集内容もDB平文列へ残さない設計に乗れる。
- 既存FrontendにはDM整理の保存、scan、生成、承認までの導線があり、編集UIを追加する場所が明確である。
- PlaywrightのDM整理happy pathが既にあり、編集保存と承認までの回帰を追加しやすい。

## 改善点

- 現在の整理ドラフト表示はread-onlyで、AI誤要約や候補の誤りを承認前に修正できない。
- Backendは現状、approved/stale/rejectedのドラフトもPATCHで更新できるため、UI制御だけでは監査上不十分である。
- Issue候補/要件候補/リスクの編集粒度が未定義であり、長文や複数候補でUIが崩れるリスクがある。
- confidence欠落や空配列の表示/保存時の崩れをE2Eで固定していない。
- Review Center連動前のため、編集保存がレビュー履歴とまだ統合されていない。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | AI整理結果を編集できない | summary、決定事項、未解決事項、アクション、Issue候補、要件候補、リスクの編集UIを追加 |
| P1 | approved/stale/rejectedをAPIから更新できる | Backendで `draft` / `needs_revision` のみ更新可能にする |
| P1 | 編集保存のE2E不足 | 編集、保存、承認までのPlaywrightを追加 |
| P2 | 候補編集UIの複雑化 | 初期sliceはtextareaベースで長文と複数候補に耐える形にする |
| P2 | Review Center履歴未統合 | ISSUE-037で連動する |

## 次アクション

1. Backendに編集可能statusのガードとrequest specを追加する。
2. Frontendに編集state、PATCH保存処理、保存ボタン、読み取り専用状態を追加する。
3. Playwrightで編集保存、空配列、承認済み編集不可を検証する。
4. 実装レビューを保存する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | AI整理ドラフトを人間が修正してから承認できる状態にする |
| Strategy | 既存PATCH APIを使い、Frontend中心で編集UIを追加しつつAPI側でも編集不可statusを守る |
| Tactics | textarea編集、line-based正規化、status gate、E2E、実装レビュー |
| Assessment | ISSUE-036は実装に進めてよい。ただしReview Center連動はISSUE-037へ分離する |
| Conclusion | 実装開始 |
| Knowledge | AI出力を承認するUXでは、編集可能性と編集不可状態の明示がレビュー品質に直結する |

## 判定

合格。

ISSUE-036は実装へ進める。ただしBackend status gate、E2E、レビュー保存まで完了してからPR化する。
