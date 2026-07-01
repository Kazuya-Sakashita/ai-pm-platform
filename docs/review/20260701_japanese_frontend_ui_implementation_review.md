# 2026-07-01 日本語Frontend UI実装レビュー

## 評価日時

2026-07-01 20:09:37 JST

## 評価担当

Codex

- Product Manager
- UI/UX Designer
- Frontend Architect
- QA
- Tech Lead

外部AIレビュー: Claude/ChatGPT等の外部レビューは未実施。現時点ではCodex一次レビューとして保存し、外部レビュー待ちとする。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010

## 対象Issue

- ISSUE-021
- GitHub Issue #21

## 対象成果物

- `frontend/app/workspace-client.tsx`
- `frontend/e2e/meeting-workspace.spec.ts`
- `docs/product/20260701_japanese_display_policy.md`
- `docs/product/20260701_japanese_ui_glossary.md`

## 良かった点

- Meeting Workspaceの主要見出し、ボタン、ラベル、空状態、ステータス、成功/失敗メッセージを日本語化した。
- API enumやDB statusの物理値は英語のまま維持し、UI表示のみ `statusLabel` / `targetLabel` / `displayMessage` で日本語化した。
- GitHub公開、reconciliation、OpenAPI validation、Review blockerなど、複雑な状態も日本語で読めるようにした。
- GitHub未接続、AI応答不正、rate limit、機密情報検出など主要エラーを日本語表示へ変換した。
- Playwright E2Eを日本語UI文言へ更新し、主要導線、失敗導線、pending reconciliation導線を検証した。
- 日本語UI用語集と実装が概ね対応しており、表記揺れを減らす土台ができた。

## 改善点

- `displayMessage` / `statusLabel` / `targetLabel` が `workspace-client.tsx` 内にあり、将来画面が増えると重複しやすい。
- API safe detail本体はまだ英語のままで、Frontend側の一部message mapに依存している。
- AI生成されるIssue本文、Review本文、要件定義本文の日本語テンプレート統一は未完了。
- OpenAPI、GitHub、Issueなど固有名詞まわりは意図的に英語を残しているが、用語集との自動チェックはない。
- 長い日本語ボタンが狭い幅で収まるかのビジュアル回帰確認はPlaywrightの機能E2E中心で、スクリーンショット比較までは未実施。
- 多言語切り替えやi18n基盤は非スコープのため、将来英語UIも必要になる場合は再設計が必要。

## 優先順位

- P0: 今回の日本語UI変更が既存主要E2Eを壊していないことをCIで確認する。
- P1: 表示変換helper/mapを `frontend/lib` へ分離し、再利用可能にする。
- P1: API safe detailの日本語化範囲を整理し、Backend側で返すべき文言を決める。
- P1: AI生成テンプレートの日本語統一を `docs/ai/` と実装に反映する。
- P2: 日本語UIのスクリーンショット確認、狭幅表示確認、WCAG観点のフォーカス/補助文改善を行う。

## 次アクション

- CI完了後、GitHub Issue #21へ検証結果を同期する。
- `displayMessage` / `statusLabel` / `targetLabel` の共通化Issueまたは残タスクを追加する。
- Backend safe detailとAI生成テンプレートの日本語方針を別レビューで整理する。
- 主要画面のスクリーンショット確認を追加する。

## Issue番号

- ISSUE-021
- GitHub Issue #21

## レビュー結果

Frontend UI実装フェーズとしては合格。主要ユーザー導線は日本語化され、Playwrightでも確認できた。ただし世界レベルのSaaS基準では、表示変換helperの共通化、Backend safe detail、AI生成テンプレート、視覚回帰確認が残るため、ISSUE-021はまだ継続が妥当。

## 検証結果

- `git diff --check`: pass
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 7 passed
