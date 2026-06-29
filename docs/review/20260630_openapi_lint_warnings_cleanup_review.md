# 20260630_openapi_lint_warnings_cleanup_review

## 評価日時

2026-06-30 07:25 JST

## 評価担当

Codex as CTO, Tech Lead, Backend Architect, Frontend Architect, QA, Security Engineer

## 使用フレームワーク

G-STACK、ISO25010、DDD、OpenAPI contract review

## 評価対象

- `docs/api/openapi.yaml`
- `redocly.yaml`
- `package.json`
- `frontend/lib/api/schema.d.ts`
- `npm run api:verify`

## 良かった点

- Redocly lintのOpenAPI契約warningを55件から0件へ削減した。
- 全operationに `operationId` を追加し、Frontend/Backend codegenとcontract testで安定参照できる状態にした。
- 全tagにdescriptionを追加し、API catalogとしての可読性を上げた。
- list系とreview action系に不足していた4XX responseを追加した。
- `info.license` に `LicenseRef-Proprietary` を追加した。
- server URLから `example.com` と `localhost` を外し、local devはclient環境変数で上書きする方針に整理した。
- `openapi-typescript` をRedocly config駆動に寄せ、CLI引数二重指定warningを解消した。

## 改善点

- local Nodeが `v22.7.0` のため、Redocly CLIのengine warningは表示される。これはOpenAPI契約warningではないが、CI導入前にNode `22.12.0` 以上へ合わせる必要がある。
- 4XX responseはまだ最小限であり、認可エラー `403`、競合 `409`、rate limit `429` の適用範囲はBackend実装時に再評価が必要。
- server URLは `.test` placeholderのままなので、正式ドメイン決定時にADRまたはrelease docへ反映する必要がある。
- generated schemaの差分が大きいため、今後はCIでschema driftを検出する必要がある。

## 優先順位

1. P0: ISSUE-018を完了扱いにしてGitHub #18をcloseする
2. P0: ISSUE-015でBackend実装に入る前にOpenAPI contractを基準にする
3. P0: CI導入時にNode `22.12.0` 以上を使う
4. P1: Backend実装時に4XX response coverageを再評価する
5. P1: schema drift checkをCIへ追加する

## 次アクション

- `docs/api/openapi.yaml` と `frontend/lib/api/schema.d.ts` をcommit/pushする。
- GitHub #18をcloseする。
- 次にISSUE-015のBackend Projects/Meetings/Reviews/Jobs MVPへ進む。

## Issue番号

ISSUE-018 / GitHub #18

GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/18
