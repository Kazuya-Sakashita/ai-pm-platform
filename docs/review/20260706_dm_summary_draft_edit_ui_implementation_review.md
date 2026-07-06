# DM整理ドラフト編集UI実装レビュー

## 評価日時

2026-07-06 11:42:32 JST

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

## 評価対象

- `backend/app/models/conversation_summary_draft.rb`
- `backend/app/controllers/api/v1/conversation_summary_drafts_controller.rb`
- `backend/spec/requests/api/v1/conversation_summary_drafts_spec.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/app/globals.css`
- `frontend/e2e/meeting-workspace.spec.ts`
- `docs/issue/ISSUE-036_discord_dm_summary_draft_edit_ui.md`

## 良かった点

- DM整理ドラフトの主要項目を承認前に編集保存できるようになり、AI誤要約をそのまま承認するリスクを下げた。
- Frontendは既存OpenAPI generated clientでPATCHし、API契約と実装の経路を揃えた。
- Backendでも `draft` / `needs_revision` 以外の更新と承認を拒否し、UIだけに依存しない安全な状態制御にした。
- 承認後は保存ボタンがdisabledになり、textareaもreadonlyになって編集不可状態が画面で明確になった。
- Playwrightで編集、保存、空配列、承認後readonlyまで一連の導線を固定した。
- Conversation Summary Draftの暗号化payload保存方針を維持し、編集内容がDB平文列へ残らない既存設計を壊していない。

## 改善点

- Issue候補/要件候補はtextareaベースの初期sliceであり、候補ごとのカード編集、追加、削除、並べ替えは未実装である。
- line-based正規化では、本文内に区切り文字が多い長文候補の編集体験はまだ粗い。
- 編集履歴や差分表示はなく、誰がどの項目をどう修正したかはAuditLogの更新イベント以上には追えない。
- Review Centerとはまだ連動しておらず、編集後レビュー依頼や差し戻し状態はISSUE-037へ残る。
- 複数人同時編集、競合検知、保存前差分確認は非スコープである。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | Review Center未連動 | ISSUE-037でレビュー依頼、ブロッカー、承認条件へ接続する |
| P2 | 候補編集の粒度が粗い | 候補カード編集と追加/削除/並べ替えを後続Issueで検討する |
| P2 | 編集履歴が薄い | AuditLog metadataまたはReview履歴への差分保存を検討する |
| P2 | 同時編集未対応 | 実ユーザー認証と編集競合要件が出た段階で設計する |

## 次アクション

1. PRを作成し、CI成功後にマージする。
2. GitHub Issue #36をクローズする。
3. 次はISSUE-037でReview CenterとConversation Summary Draft承認を連動する。
4. 候補カード編集や編集差分履歴は必要に応じて後続Issue化する。

## 検証結果

- `bundle exec rspec spec/requests/api/v1/conversation_summary_drafts_spec.rb`: 10 examples, 0 failures
- `bundle exec rspec`: 272 examples, 0 failures
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run api:verify`: success
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts --grep "imports, scans"`: 1 passed

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM整理ドラフトを承認前に人間が修正できるようにする |
| Strategy | 既存PATCH APIをFrontendへ接続し、Backend status gateで承認済み/古いドラフトを保護する |
| Tactics | 編集フォーム、保存ボタン、readonly表示、request spec、Playwright E2E |
| Assessment | ISSUE-036のMVP要件は満たした。候補カード編集とReview Center連動は後続課題 |
| Conclusion | PR化してよい |
| Knowledge | AI生成物の承認UXでは、編集できる状態と編集できない状態をAPIとUIの両方で揃える必要がある |

## STRIDE

| Threat | 実装対応 |
| --- | --- |
| Spoofing | ProjectMembershipによる既存認可を維持 |
| Tampering | approved/stale/rejectedのPATCHとapproveを拒否 |
| Repudiation | 更新時にAuditLogを記録 |
| Information Disclosure | 暗号化payload保存を維持 |
| Denial of Service | 追加処理は同期PATCHのみでジョブ増加なし |
| Elevation of Privilege | editorでは承認不可の既存Policyを維持 |

## 判定

合格。

ISSUE-036は完了可能。ただし、Review Center連動、候補カード編集、編集差分履歴は世界レベルSaaS基準では後続改善として残す。
