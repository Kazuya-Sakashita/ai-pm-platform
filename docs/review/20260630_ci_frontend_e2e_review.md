# 2026-06-30 CI Frontend E2E 統合レビュー

## 評価日時

2026-06-30 11:05 JST

## 評価担当

Codex as DevOps / QA / Tech Lead / CTO / Security Engineer / Product Manager

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- DORA Metrics
- SPACE Framework
- ISO25010
- OWASP Top 10

## 良かった点

- GitHub Actions CIを新規追加し、Backend RSpec、Rails autoload、OpenAPI verify、Frontend build、Playwright E2Eを一連で検証できるようにした。
- PostgreSQL serviceをCI内に立て、Rails test databaseをprepareしてからbackend/frontend統合検証へ進む構成にした。
- E2EではRails APIを起動し、Frontendが実APIへ接続する形を維持した。
- OpenAI live keyへ依存しないよう `MINUTES_GENERATION_PROVIDER=deterministic` を明示し、CIの再現性を優先した。
- 失敗時にPlaywright report、test-results、backend server logをartifactとして保存するようにした。

## 改善点

- CI workflowはGitHub Actions上でgreenを確認済み。
- Playwrightはhappy path 1本のみで、failed job、secret blocked、validation errorのE2Eは未追加。
- E2EのDB cleanupがなく、CIではrunごとに破棄されるが、ローカルdevelopment DBではデータが蓄積する。
- 本番OpenAI API keyでのlive smoke testはまだCIに含めていない。
- CI durationは初回greenで約1分45秒。flake rateとartifact運用の継続実績はまだない。

## 優先順位

1. P0: failed job / secret blocked / validation errorのE2Eを追加する
2. P0: 本番OpenAI API keyでのlive smoke testを手動またはprotected CI jobへ分離する
3. P1: E2E test data cleanupまたはtest-only DB resetを整備する
4. P1: CI badge、branch protection、required checksを設定する
5. P1: GitHub ActionsのNode.js 20 deprecation annotationへ対応する
6. P1: CI durationとflake率をDORA/SPACE観点で追跡する

## 次アクション

- ISSUE-002はlive OpenAI smokeとReview Center統合が残るためopen継続。
- 次はfailure path E2E、または本番OpenAI API keyを使うlive smoke手順整備へ進む。

## Issue番号

- GitHub Issue: #2

## G-STACK

### Goal

Meeting Workspaceの主要フローがpushごとに壊れていないことを自動確認する。

### Strategy

DB、backend、frontend、E2Eを1つのCI jobで順番に検証し、MVP段階の複雑さを抑える。

### Tactics

- PostgreSQL serviceを利用
- Ruby/Nodeを公式setup actionで固定
- `bundle exec rspec` と `npm run api:verify` を実行
- Rails APIをtest環境で起動
- `npm run frontend:e2e` を実行
- 失敗時artifactを保存

### Assessment

CIとしての最低限の品質ゲートはできた。ただし、failure path coverageとbranch protectionは未整備である。

### Conclusion

合格。workflowは採用する。ただし、ISSUE-002全体はlive OpenAI smokeとReview Center統合が残るためopen継続。

### Knowledge

Frontend E2EはRails APIが必要であるため、CIではRails serverをtest環境で起動し、`NEXT_PUBLIC_API_BASE_URL` を `http://localhost:3001/api/v1` に固定する。

## DORA / SPACE

| 観点 | 評価 | 改善 |
| --- | --- | --- |
| Deployment frequency | CI導入で頻繁な変更に耐えやすい | branch protectionが必要 |
| Lead time | push時の回帰検出が早くなる | job duration監視が必要 |
| Change failure rate | smoke coverageで低減見込み | failure path不足 |
| MTTR | artifact保存で調査しやすい | backend logとtrace運用を標準化 |
| SPACE satisfaction | 開発者の安心感は上がる | flaky test対策が必要 |

## 検証結果

ローカル:

- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 1 passed
- `npm run api:verify`: 成功。OpenAPI contract warningなし
- `bundle exec rspec`: 24 examples, 0 failures
- `npm audit --omit=dev`: 0 vulnerabilities

GitHub Actions:

- 初回Run `28417183475`: 失敗
- 原因: `backend/Gemfile.lock` の `PLATFORMS` が `arm64-darwin` のみで、GitHub Actions runnerの `x86_64-linux` に対応していなかった
- 対応: `bundle lock --add-platform x86_64-linux` でlockfileへLinux platformとLinux用nokogiriを追加
- 修正後Run `28417288092`: 成功、verify job 1m45s
- Annotation: `actions/checkout@v4` と `actions/setup-node@v4` にNode.js 20 deprecation warningあり。jobは成功しているが、今後のActionsメンテナンスで対応が必要。

## 判定

合格。

CI workflowはGitHub Actions上でもgreenを確認した。ただし、failure path E2E、live OpenAI smoke、branch protectionは未完了であり、ISSUE-002全体はopen継続。
