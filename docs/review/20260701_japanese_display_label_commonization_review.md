# 2026-07-01 日本語表示ラベル共通化レビュー

## 評価日時

2026-07-01 20:29:32 JST

## 評価担当

Codex

- Frontend Architect
- Tech Lead
- QA
- UI/UX Designer
- Product Manager

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- ISO25010
- WCAG

## 対象Issue

- ISSUE-021
- GitHub Issue #21

## 対象成果物

- `frontend/lib/display-labels.ts`
- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`

## 良かった点

- `displayMessage`、`statusLabel`、`targetLabel`、`yesNoLabel` を `frontend/lib/display-labels.ts` へ切り出し、表示変換を画面コンポーネントから分離した。
- API enum、DB status、backend safe detailの物理値は変更せず、ユーザー向け表示だけを日本語化する境界を維持した。
- Meeting Workspace以外の画面追加時にも同じ日本語表示ラベルを再利用しやすくなった。
- 共通化後もPlaywright E2Eで主要導線、失敗導線、GitHub reconciliation導線を確認できた。

## 改善点

- `display-labels.ts` は静的mapであり、用語集ドキュメントとの自動整合チェックはまだない。
- Backend safe detailは依然として英語中心で、Frontend側のmessage mapに依存している。
- AI生成されるIssue本文、Review本文、要件定義本文の日本語テンプレート統一は未完了。
- 長い日本語ボタンの狭幅スクリーンショット確認は未実施。

## 優先順位

- P0: CIで共通化後のfrontend build / E2Eが通ることを確認する。
- P1: Backend safe detailの日本語化範囲を整理する。
- P1: AI生成テンプレートの日本語統一を `docs/ai/` と実装に反映する。
- P2: 用語集と `display-labels.ts` の差分検査を追加する。
- P2: 狭幅/スクリーンショット確認を追加する。

## 次アクション

- GitHub Issue #21へ共通化と検証結果を同期する。
- CI成功後、Issue #21の残作業をBackend safe detail、AI生成テンプレート、視覚確認へ絞り込む。
- 次の改善Issueとして、用語集と表示ラベルmapの整合チェックを検討する。

## Issue番号

- ISSUE-021
- GitHub Issue #21

## レビュー結果

日本語表示ラベル共通化としては合格。画面内に閉じていた表示変換を `frontend/lib` に分離したことで、保守性と拡張性は改善した。ただし世界レベルのSaaS基準では、Backend safe detail、AI生成テンプレート、視覚回帰確認、用語集との自動整合が残るため、Issue #21は継続が妥当。

## 検証結果

- `git diff --check`: pass
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 9 passed
