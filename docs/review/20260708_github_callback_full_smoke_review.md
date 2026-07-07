# GitHub callback full smokeレビュー

## 評価日時

2026-07-08 07:29:11 JST

## 評価担当

Codex、Security Engineer、Frontend Architect、Backend Architect、QA、Product Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010
- Release Check

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 対象

- Frontend `/github/callback`
- Backend `POST /api/v1/integrations/github/callback`
- GitHub App installation verification
- `integration_accounts`
- GitHub connection AuditLog

## 実施内容

- smoke用Project `9ddb5d9e-4c68-4834-a838-fc1411e2a5c8` に `local-demo-owner` のowner membershipを作成した。
- 既存backendが `.env` 未読込だったため、最初のcallbackは `github_app_not_configured` で安全に失敗した。
- backendを `.env` 読込付きで再起動した。
- `POST /api/v1/projects/{project_id}/integrations/github/connect` からone-time stateを発行した。
- 生成されたinstallation URLが `github.com/apps/ai-pm-platform/installations/new` で、state queryを含むことを確認した。
- `/github/callback?state=...&installation_id=145067753&setup_action=install` をブラウザで開き、Frontendから実backend callback APIへPOSTされることを確認した。
- GitHub API照合後、画面に「接続が完了しました」「GitHub連携が完了しました。」が表示されることを確認した。
- 画面のGitHub接続結果に `Kazuya-Sakashita/ai-pm-platform`、`Kazuya-Sakashita`、`接続済み` が表示されることを確認した。
- state生値が画面テキストへ表示されないことを確認した。
- 一時保存したone-time stateファイルを削除した。

## 証跡

- commit SHA: `6c5d97c984491670d075ed22e59bdced8baca8ea`
- 環境: local development
- 対象repository: `Kazuya-Sakashita/ai-pm-platform`
- installation id: `145067753`
- Project id: `9ddb5d9e-4c68-4834-a838-fc1411e2a5c8`
- IntegrationAccount id: `15248c6d-6c97-4bc5-b3a8-0ff2ace37979`
- connection status: `connected`
- issues write permission: `true`
- last_error_safe: `null`
- 画面summary: `処理=インストール`、`状態=接続済み`、`リポジトリ=Kazuya-Sakashita/ai-pm-platform`、`アカウント=Kazuya-Sakashita`
- console error count: `0`
- AuditLog actions:
  - `github.connect.started`
  - `github.connect.failed`
  - `github.connect.completed`

## 良かった点

- Frontend callback pageから実backend callback APIへPOSTし、GitHub API照合込みで接続完了まで確認できた。
- callback画面にstate生値が表示されず、秘密情報露出を避けられている。
- 成功時に `integration_accounts` が `connected` になり、GitHubから取得したaccount、repository、permissionsが保存された。
- 失敗時も `github.connect.failed` AuditLogにsafe errorだけが保存され、調査可能性がある。
- `.env` 未読込の起動不備を安全に検出し、credentialやtokenを漏らさず復旧できた。

## 改善点

- backend起動時に `.env` を読まないと実GitHub callbackが失敗する。ローカルrunbookへ起動コマンドを明記する必要がある。
- callback success smokeはlocal環境で実施したが、staging/productionの公開URLからGitHub画面を経由する確認は未実施。
- callbackページの見出しは画面テキストでは確認できたが、ブラウザSkillのrole locatorでは一致しなかった。アクセシビリティの見出し/ARIA確認は追加余地がある。
- connect/callback endpointのrate limitは未確認。
- GitHub webhook live delivery smokeは未実施。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | callback full smoke結果をISSUE-004へ同期 | 親Issueのクローズ判断に必要 |
| P1 | backend `.env` 読込付き起動手順をrunbookへ反映 | 同じ失敗の再発防止 |
| P1 | staging/production callback URL smoke | GitHub画面経由の実到達性確認 |
| P1 | webhook live delivery smoke | GitHub側変更同期の実証跡が必要 |
| P2 | callbackページのアクセシビリティ深掘り | role locator不一致の原因確認 |

## 次アクション

1. ISSUE-004へcallback full smoke完了を同期する。
2. GitHub App live smoke runbookへ `.env` 読込付きbackend起動手順を追記済み。
3. GitHub webhook live delivery smokeへ進む。
4. staging/production worker smokeへ進む。

## 判定

条件付き合格。

Frontend callback pageから実backend callback APIへ到達し、GitHub App installation verification、`integration_accounts` 保存、成功画面、AuditLogを確認できた。state生値の画面露出もなかった。一方でstaging/production公開URL、webhook live delivery、worker smokeは未完了のため、ISSUE-004はまだクローズしない。

## Knowledge

GitHub callback smokeでは、stateを一度使うと失敗時も再利用できない。backend起動環境が未設定の場合は `github_app_not_configured` で安全に失敗するが、再試行には必ず新しいconnection stateを発行する必要がある。
