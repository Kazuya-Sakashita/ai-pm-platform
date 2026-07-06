# ISSUE-036: Discord DM整理ドラフト編集保存UIを実装する

## Issue番号

ISSUE-036

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/36

登録日: 2026-07-05
状態: CLOSED
クローズ日時: 2026-07-06 11:47:17 JST

## 背景

ISSUE-022のFrontend MVPでは、Conversation Summary Draftをread-onlyで表示し、承認理由付きでapproveできるようになった。一方で、AI整理結果の誤要約、抜け漏れ、表現修正、Issue候補の調整をユーザーが画面上で編集できない。

DMは文脈が短く曖昧になりやすいため、AI出力をそのまま承認するより、人間が整理内容を修正してから承認できることが重要である。

## 目的

`PATCH /conversation-summary-drafts/{conversation_summary_draft_id}` をFrontendから利用し、整理要約、決定事項、未解決事項、アクション、Issue候補、要件候補、リスクを編集保存できるようにする。

## 完了条件

- DM整理ドラフトの主要項目を編集できる
- 保存時にOpenAPI generated clientを使ってPATCHしている
- 保存後にstatus、updated_at、表示内容が更新される
- stale / approved / rejectedの編集可否が明確である
- 空配列、長文、複数候補、confidence欠落時にUIが崩れない
- Playwright E2Eで編集、保存、承認まで検証している
- 表示文言が日本語で統一されている
- レビュー結果が `docs/review/` に保存されている

## スコープ

- Frontend編集UI
- PATCH API接続
- E2E追加
- 表示ラベル追加
- 必要最小限のBackend validation調整
- UI/UXレビュー

## 非スコープ

- Structured Outputs provider実装
- Review Center連動
- 複数人同時編集
- rich text editor
- GitHub Issueへの直接公開

## 関連レビュー

- `docs/review/20260705_discord_dm_frontend_mvp_review.md`
- `docs/review/20260706_dm_summary_draft_edit_ui_design_review.md`
- `docs/review/20260706_dm_summary_draft_edit_ui_implementation_review.md`

## レビュー結果

Codex一次レビューでは、read-only表示のまま承認できるMVPは早期検証には有効。ただし世界レベルSaaS基準では、AI誤要約を修正できない承認フローは危険であり、人間レビューの品質を担保できない。

2026-07-06に実装完了。既存PATCH APIをFrontendから利用し、整理要約、決定事項、未解決事項、アクション項目、Issue候補、要件候補、リスクを承認前に編集保存できるようにした。Backendでは `draft` / `needs_revision` 以外の更新と承認を拒否し、approved/stale/rejectedの状態をAPI側でも保護した。Playwrightで編集、保存、空配列、承認後の読み取り専用化を検証した。

## 優先度

P1

理由:

- AI出力の人間レビュー品質に直結する
- #35のAI provider接続と独立して進められる
- 既存PATCH APIがあるためFrontend中心で進めやすい

## 次アクション

1. `ConversationSummaryDraftsController#update` の契約と現在のschemaを確認する。
2. 編集UIの対象項目と保存単位を決める。
3. Playwrightで編集保存happy pathと空配列ケースを追加する。
4. 実装レビューを保存する。

## 実装結果

完了。

### 主な変更

- DM整理ドラフトに編集フォームと保存ボタンを追加した。
- 保存時にOpenAPI generated client経由で `PATCH /conversation-summary-drafts/{conversation_summary_draft_id}` を呼び出すようにした。
- `draft` / `needs_revision` のみ編集/承認可能にし、approved/stale/rejectedは読み取り専用にした。
- Backendでも編集不可statusを拒否し、UI制御だけに依存しないようにした。
- Playwright E2Eへ編集保存、空配列、承認後readonly確認を追加した。

### 検証結果

- `bundle exec rspec spec/requests/api/v1/conversation_summary_drafts_spec.rb`: 10 examples, 0 failures
- `bundle exec rspec`: 272 examples, 0 failures
- `npm run display:check`: success
- `npm run frontend:build`: success
- `npm run api:verify`: success
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts --grep "imports, scans"`: 1 passed

### 残リスク

- 候補編集はtextareaベースの初期sliceであり、候補ごとの構造化カード編集や並べ替えは未実装。
- Review Center連動はISSUE-037で対応する。
- 複数人同時編集や差分履歴は非スコープ。
