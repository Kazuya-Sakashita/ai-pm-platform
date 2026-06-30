# 2026-06-30 Frontend Playwright Smoke Test レビュー

## 評価日時

2026-06-30 10:15 JST

## 評価担当

Codex as QA / Frontend Architect / Tech Lead / Product Manager / UI/UX Designer / Security Engineer

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- HEART
- WCAG
- ISO25010
- DORA Metrics

## 良かった点

- Meeting Workspaceの主要ユーザーフローをPlaywrightで自動化した。
- Project作成、Meeting保存、Minutes生成、Job取得、Minutes反映、Review作成、Minutes承認まで、MVPの中心価値を1本のsmoke testで検証した。
- テスト開始時にRails API healthを確認し、backend未起動時に原因が分かりやすいようにした。
- `npm run frontend:e2e` を追加し、Frontend検証手順をREADMEへ記録した。
- スクリーンショットQAで1280px付近のReview gate回り込みを検出し、CSS grid配置を修正した。
- `npm run frontend:build`、`npm run frontend:e2e`、`npm run api:verify`、`bundle exec rspec`、`npm audit --omit=dev` が成功した。

## 改善点

- Playwrightはまだ1本のhappy pathのみ。OpenAI failed job、secret blocked、validation error、review request失敗のUI検証が不足している。
- Rails APIは別途起動が前提で、E2E単体でDB prepareとAPI server起動まで完結していない。
- スクリーンショットはローカル `work/meeting-workspace-smoke.png` で確認したが、CI artifactとして保存する仕組みがない。
- Desktop Chromeのみで、mobile/tabletやFirefox/WebKitの検証は未実施。
- test data cleanupがなく、development DBにE2E Projectが蓄積する。
- 認証/テナント境界がないため、E2Eは実運用のアクセス制御を検証していない。

## 優先順位

1. P0: E2Eでfailed job / secret blocked / validation errorのUIを追加検証する
2. P0: CIでfrontend build、backend spec、frontend e2eを実行する
3. P0: 本番OpenAI API keyでlive generation smoke testを実施する
4. P1: E2E用のDB resetまたはtest project cleanupを追加する
5. P1: screenshot/video/traceをCI artifactとして保存する
6. P1: Review Center本体の一覧/解決導線をE2E対象へ追加する

## 次アクション

- ISSUE-002はPlaywright smokeとvisual QAを追加済み。ただしlive OpenAI smoke testとReview Center本体統合が残るためopen継続。
- 次はISSUE-002のlive OpenAI smoke手順整備、またはISSUE-006の認証/データ保護基盤へ進む。

## Issue番号

- GitHub Issue: #2

## G-STACK

### Goal

Discordログから議事録生成とレビュー依頼までのMVP体験が、ブラウザ上で壊れていないことを継続確認する。

### Strategy

まずhappy pathをE2E化し、重要なUI回帰を早期に検出する。failure pathとCI統合は次sliceで厚くする。

### Tactics

- `@playwright/test` を導入
- `frontend/playwright.config.ts` を追加
- `frontend/e2e/meeting-workspace.spec.ts` を追加
- screenshot QAでレイアウト崩れを検出し、CSS gridを修正

### Assessment

MVP主要フローの自動検証としては有効。ただし世界レベルSaaS基準では、failure path、CI、artifact、cleanup、access controlの検証が不足している。

### Conclusion

条件付き合格。ISSUE-002のPlaywright smoke sliceとして採用するが、完成条件にはまだ未達。

### Knowledge

1280px付近では4カラムを維持しにくいため、left rail / transcript+minutes / inspector の3カラム配置へ落とす必要がある。

## HEART

| 指標 | 評価 | 改善 |
| --- | --- | --- |
| Happiness | 主要操作が通るため手戻りが減る | error UIの検証不足 |
| Engagement | Generate/Review/Approveまで体験できる | Review Center統合が必要 |
| Adoption | smoke testで初回導線を守れる | seed/cleanupが必要 |
| Retention | 回帰を早期検知できる | CI artifactが必要 |
| Task Success | happy pathは成功 | failure pathが未検証 |

## 検証結果

- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 1 passed
- `npm run api:verify`: 成功。OpenAPI contract warningなし。Node version warningのみ既知
- `bundle exec rspec`: 24 examples, 0 failures
- `npm audit --omit=dev`: 0 vulnerabilities
- `npx playwright screenshot --full-page http://localhost:3000 work/meeting-workspace-smoke.png`: 成功

## 判定

条件付き合格。

Playwright smoke testとvisual QAにより、#2のUI検証は前進した。ただし、live OpenAI、failure path、CI統合、認証/テナント検証が未完了であるため、GitHub #2はopen継続。
