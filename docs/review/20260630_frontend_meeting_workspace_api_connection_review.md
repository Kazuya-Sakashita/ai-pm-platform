# 2026-06-30 Meeting Workspace Frontend API接続レビュー

## 評価日時

2026-06-30 09:45 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / Frontend Architect / Backend Architect / Security Engineer / QA / UI/UX Designer / Product Manager

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- STRIDE
- RICE

## 良かった点

- Meeting Workspaceを第一画面にし、Project作成、Meeting保存、Minutes生成、Job取得、Minutes表示、編集、承認、Review作成までAPI接続した。
- OpenAPI generated clientを使い、FrontendとAPI契約の乖離を抑えた。
- 静的プロトタイプの情報密度、色、余白、review gateの方向性をNext UIへ移植した。
- lucide-reactを導入し、主要actionにアイコンを持たせた。
- `npm run frontend:build`、`npm run api:verify`、local API smoke testが成功した。
- `npm audit --omit=dev` は0件。Next内部PostCSS脆弱性はnpm overridesで解消した。

## 改善点

- ブラウザスクリーンショットによる視覚QAとPlaywright smoke testは未実装。世界レベルSaaS基準では、UIの重なり、フォーカス、主要操作を自動検証すべき。
- 認証、テナント境界、ユーザー権限が未実装のため、実運用データを扱うには危険。
- Review作成は最小実装で、Review Center側の一覧/解決/accepted risk導線には未接続。
- Minutes生成は本番OpenAI keyでlive検証していない。
- 長文Discordログ、API失敗、secret block時のUXは初期表示に留まり、再試行や詳細導線が弱い。
- mobileは閲覧可能だが、MVPの主対象はdesktopであり、狭幅操作の完成度は不足している。

## 優先順位

1. P0: Playwright smoke testでProject作成、Meeting保存、Generate Minutes、Request Reviewを検証する
2. P0: 本番OpenAI API keyでlive smoke testを行う
3. P0: Review CenterへReview一覧/解決導線を接続する
4. P1: API error状態、secret blocked、OpenAI failed jobのUIを強化する
5. P1: 認証/テナント境界をISSUE-006で実装する
6. P1: browser screenshotを保存し、visual QAレビューを追加する

## 次アクション

- ISSUE-002はFrontend接続まで進んだが、live OpenAI smoke testとPlaywrightが未完了のためopen継続。
- 次はISSUE-002のPlaywright smoke test、またはISSUE-006の認証/セキュリティ基盤へ進む。

## Issue番号

- GitHub Issue: #2

## G-STACK

### Goal

DiscordログからMinutes生成とレビュー依頼までを、ユーザーがブラウザ上で実行できるようにする。

### Strategy

OpenAPI clientを使い、Backendで実装済みのProject/Meeting/Minutes/Review APIを薄いNext UIへ接続する。

### Tactics

- Next.js App Routerを導入
- Meeting Workspaceを第一画面にする
- Jobを経由してMinutesを取得する
- `npm audit` とbuildで依存/型の安全性を確認する

### Assessment

MVP価値の体験は作れた。ただし、E2E自動化、live OpenAI、認証、Review Center統合がないため、完成ではない。

### Conclusion

条件付き合格。#2のUI接続sliceとして採用するが、GitHub #2はopen継続。

### Knowledge

`generate-minutes` は `job_id` を返すため、Frontendは `GET /jobs/{job_id}` で `target_id` を取得し、`GET /minutes/{minutes_id}` へ進む必要がある。

## HEART

| 指標 | 評価 | 改善 |
| --- | --- | --- |
| Happiness | 操作導線は短い | error時の安心感が弱い |
| Engagement | MeetingからReviewまで到達可能 | Review Center統合が必要 |
| Adoption | 初回操作しやすい | project seed/onboardingが必要 |
| Retention | audit/job/model表示あり | history比較が未実装 |
| Task Success | API smokeは成功 | Playwrightで継続検証が必要 |

## 検証結果

- `npm run frontend:build`: 成功
- `npm run api:verify`: 成功。OpenAPI contract warningなし。Node version warningのみ既知
- `npm audit --omit=dev`: 0 vulnerabilities
- `curl -I http://localhost:3000/`: 200 OK
- `curl -s http://localhost:3001/api/v1/health`: `{"status":"ok"}`
- local API smoke: Project作成 -> Meeting保存 -> Minutes生成 -> Job取得 -> Minutes取得 成功
- ブラウザスクリーンショットQA: 未実施
