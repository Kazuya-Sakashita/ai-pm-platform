# DM整理ドラフト レビューセンター連動 実装レビュー

## 評価日時

2026-07-06 12:15:20 JST

## 評価担当

Codex / Product Manager / CTO / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA / UI/UX Designer

外部AIレビュー: Claude/ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- WCAG
- HEART

## Issue番号

ISSUE-037 / GitHub #37

## 対象

- `backend/app/models/review.rb`
- `backend/app/controllers/api/v1/reviews_controller.rb`
- `backend/spec/requests/api/v1/reviews_spec.rb`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`
- `docs/review/20260706_conversation_summary_review_center_design_review.md`

## 実装概要

DM整理ドラフトをレビューセンターの統制対象として扱えるようにし、`conversation_summary_draft` のレビュー作成、一覧取得、状態表示、承認前ブロック、レビュー解決導線を追加した。

Backendでは `Review::TARGET_TYPES` と `ReviewsController#project_for_review_target` を拡張し、Conversation Summary Draftの所属プロジェクト境界を既存Review APIで解決できるようにした。

FrontendではDM整理パネルにレビュー依頼、レビュー対応済み、レビュー状態表示を追加し、未対応または対応が必要なレビューがある場合は整理ドラフト承認を停止するようにした。

## 良かった点

- OpenAPIに既に存在していた `conversation_summary_draft` target typeへ実装を追従し、契約と実装の乖離を解消した。
- DM由来情報の承認がレビューセンター状態に依存するようになり、AI PMとしての監査可能性が上がった。
- UIボタン無効化だけでなく、承認処理内でも未解決レビューを止めており、防御が二重化されている。
- Playwrightでレビュー依頼、承認ブロック、レビュー解決後の承認可能状態を検証できている。
- 表示ラベルチェックで英語表記を検出し、日本語UIへ修正できた。

## 改善点

- 現状は最新または未解決レビューを1件表示するだけで、過去レビュー履歴をDM整理パネル内で時系列表示できない。
- `action_required` を作成するUIはまだなく、レビュー依頼直後の状態は `open` が中心である。
- レビュー解決操作は簡易的な「レビュー対応済み」であり、誰が何を確認したかの入力欄はまだ薄い。
- レビューセンター全体の一覧ビューはDM整理ドラフト専用のフィルタや検索を持っていない。
- 外部AI複数レビューは未実施で、Codex一次レビューに留まっている。

## 優先順位

| Priority | 指摘 | 改善案 |
| --- | --- | --- |
| P1 | 承認前ブロックは実装済み | 今回完了。回帰防止として対象E2Eを維持する |
| P1 | Backend project境界は実装済み | 今回完了。今後は `conversation_import` 側レビューも同様にE2E化する |
| P2 | レビュー履歴が最新1件表示 | DM整理パネルにレビュー履歴の折りたたみ一覧を追加する |
| P2 | 解決理由入力が簡易 | 解決時に確認メモ、担当者、残リスクを入力できるUIへ拡張する |
| P2 | 外部AIレビュー未実施 | Claude/ChatGPTレビュー結果を追加し、Codexレビューとの差分を保存する |

## 次アクション

1. ISSUE-037のPRを作成し、CI結果を確認する。
2. GitHub Issue #37へ実装内容と検証結果を日本語でコメントする。
3. CIが通ったらPRをマージし、Issue #37をクローズする。
4. 後続Issueとしてレビュー履歴一覧と解決理由入力の改善を検討する。

## 検証結果

- `npm run frontend:build`: 成功
- `bundle exec rspec spec/requests/api/v1/reviews_spec.rb`: 8 examples, 0 failures
- `npm run api:verify`: 成功
- `npm run frontend:e2e -- --grep "imports, scans, summarizes, and approves a Discord DM paste"`: 1 passed
- `npm run display:check`: 成功
- `bundle exec rspec`: 274 examples, 0 failures

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM整理ドラフト承認をレビューセンター統制下へ置く |
| Strategy | 既存Reviews APIを拡張し、DM整理パネルからレビュー状態を読み書きする |
| Tactics | target mapping、request spec、レビュー状態state、レビュー依頼/解決ボタン、承認ブロック、E2E |
| Assessment | P1要件は満たした。履歴一覧と解決理由入力はP2改善として残す |
| Conclusion | ISSUE-037はPR化可能 |
| Knowledge | AI PMの価値はレビュー結果を表示するだけでなく、未解決リスクで次工程を止めることにある |

## 判定

条件付き合格。

ISSUE-037の完了条件は満たした。世界レベルのSaaS基準では、レビュー履歴の一覧性と解決理由の監査粒度がまだ不足しているため、後続改善候補として残す。
