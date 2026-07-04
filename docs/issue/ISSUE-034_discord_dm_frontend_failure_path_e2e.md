# ISSUE-034: Discord DM Frontendの匿名化失敗・キャンセル・権限エラーE2Eを追加する

## Issue番号

ISSUE-034

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/34

登録日: 2026-07-05

状態: 2026-07-05にcommit `53dfb88` をmainへ反映し、GitHub Actions CI `28722021043` success確認後にクローズ済み。

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
- `docs/review/20260705_discord_dm_frontend_failure_path_e2e_review.md`

## レビュー結果

ISSUE-029の実装レビューでは、匿名化happy pathは合格。ただし失敗系、キャンセル、権限エラー、モバイル表示E2Eが不足しており、復元困難な操作としてはテストが薄いと評価した。

2026-07-05にFrontend E2Eを追加。confirm cancel時にDELETE APIが呼ばれないこと、API 500/403/422で安全な日本語エラーを表示すること、失敗時にDMインポート一覧が残ること、390px mobile幅で匿名化ボタンと保持期限/audit表示が重ならないことを固定した。

良かった点:

- 復元困難な匿名化操作のキャンセル挙動をE2Eで固定した。
- 権限エラーと状態エラーの日本語safe copyを追加した。
- モバイル幅で保持期限と匿名化状態を読めることを確認した。

改善点:

- 403はISSUE-030のBackend Policy Object実装前のmock E2Eである。
- request idやsupport導線は未実装。
- 320px幅とscreen reader読み上げ順は未検証。

検証結果:

- `git diff --check`: pass
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: success
- `npm run frontend:e2e -- e2e/meeting-workspace.spec.ts --grep "DM anonymization"`: 5 passed
- GitHub Actions CI `28722021043`: success（commit `53dfb88`）
- GitHub Issue同期コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/34#issuecomment-4884039308`
- ISSUE-029同期コメント: `https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/29#issuecomment-4884039933`

## 優先度

P1

理由:

- GitHub App実機なしで進められる
- 削除/匿名化操作のUX回帰を防げる
- P0 security blockerの後続品質を底上げする

## 次アクション

1. 既存のDM E2E mockを確認する（完了）。
2. cancel/failure/permission/mobileのテストを追加する（完了）。
3. 必要ならFrontendのerror handlingと表示ラベルを修正する（完了）。
4. 検証結果をISSUE-029へ同期する（完了）。
