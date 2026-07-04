# ISSUE-034: Discord DM Frontendの匿名化失敗・キャンセル・権限エラーE2Eを追加する

## Issue番号

ISSUE-034

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/34

登録日: 2026-07-05

## 背景

ISSUE-029でDMインポート匿名化APIとFrontend導線が追加された。happy pathのPlaywright E2Eはあるが、匿名化のキャンセル、API失敗、権限エラー、モバイル幅での操作性はまだ固定されていない。

削除/匿名化は復元不能に近い重要操作であり、失敗時の表示やキャンセル時に誤って削除されないことをE2Eで保証する必要がある。

## 目的

DMインポート匿名化導線の失敗系、キャンセル、権限エラー、モバイル表示をPlaywrightで固定し、重要操作のUX回帰を防ぐ。

## 完了条件

- confirm cancel時にDELETE APIが呼ばれないことをE2Eで検証している
- DELETE API失敗時に安全な日本語エラーが表示される
- 403/422など権限・状態エラー時の表示が壊れない
- モバイル幅で匿名化ボタンと監査情報が重ならない
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts` または該当grepが成功している
- `npm run display:check` と `npm run frontend:build` が成功している
- レビュー結果が `docs/review/` に保存されている
- ISSUE-029へ同期している

## スコープ

- Playwright E2E追加
- 必要なFrontend error handling修正
- 日本語表示ラベル追加
- レビュー、Issue同期

## 非スコープ

- Backend認可Policy実装
- 認証UI
- 物理削除
- Discord自動取得

## 関連レビュー

- `docs/review/20260705_discord_dm_frontend_mvp_review.md`
- `docs/review/20260705_discord_dm_retention_delete_implementation_review.md`

## レビュー結果

ISSUE-029の実装レビューでは、匿名化happy pathは合格。ただし失敗系、キャンセル、権限エラー、モバイル表示E2Eが不足しており、復元困難な操作としてはテストが薄いと評価した。

## 優先度

P1

理由:

- GitHub App実機なしで進められる
- 削除/匿名化操作のUX回帰を防げる
- P0 security blockerの後続品質を底上げする

## 次アクション

1. 既存のDM E2E mockを確認する。
2. cancel/failure/permission/mobileのテストを追加する。
3. 必要ならFrontendのerror handlingと表示ラベルを修正する。
4. 検証結果をISSUE-029へ同期する。
