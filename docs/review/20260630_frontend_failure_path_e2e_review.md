# 2026-06-30 Frontend Failure Path E2E レビュー

## 評価日時

2026-06-30 12:05 JST

## 評価担当

Codex as QA / Security Engineer / Frontend Architect / Backend Architect / Tech Lead / Product Manager

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010

## 良かった点

- Meeting Workspaceのhappy pathに加え、validation errorとsecret blockedのE2Eを追加した。
- `SensitiveContentScanner` をprovider内ではなく `MinutesGenerationService` の共通入口で実行し、deterministic providerでもAI生成前ブロックを検証できるようにした。
- secret blocked時にfailed jobが作成され、Frontendで `job failed` と安全なエラーメッセージが表示されることを確認した。
- validation error時にFrontendがAPI error状態を表示することを確認した。
- Playwright locatorをNext route announcerと衝突しないよう、実アプリのalertへ限定した。

## 改善点

- E2Eはvalidation errorとsecret blockedを追加したが、OpenAI upstream failure、invalid AI response、rate limitのUI検証は未実装。
- Secret scanはpattern-basedであり、PIIや低信頼な機密情報の検出精度は不足している。
- secret blocked時のユーザー導線はエラー表示のみで、修正箇所のハイライトや安全なredaction提案はない。
- E2E test data cleanupがなく、ローカルdevelopment DBにテストデータが蓄積する。
- CI上の最新run確認はpush後に必要。

## 優先順位

1. P0: OpenAI upstream failure / invalid AI response / rate limitのUI検証を追加する
2. P0: 本番OpenAI API keyでのlive generation smoke testを実施する
3. P1: secret blocked時に該当種別と修正アクションをUIへ出す
4. P1: E2E test data cleanupまたはtest database利用を整備する
5. P1: Review Center本体との統合E2Eを追加する

## 次アクション

- GitHubへpushし、CIで3本のE2Eが通ることを確認する。
- ISSUE-002はlive OpenAI smokeとReview Center統合が残るためopen継続。

## Issue番号

- GitHub Issue: #2

## G-STACK

### Goal

Meeting Workspaceが成功時だけでなく、入力不備や秘密情報混入時にも安全に失敗することを保証する。

### Strategy

最初に最も発生しやすく、かつプロダクト信頼に直結するvalidation errorとsecret blockedをE2E化する。

### Tactics

- `MinutesGenerationService` の共通入口でsecret scanを実行
- validation error E2Eを追加
- secret blocked + failed job E2Eを追加
- Backend request/service specを共通scan設計に合わせて更新

### Assessment

安全な失敗の最低限は前進した。ただし、OpenAI upstream failureとlive generationは未検証であり、世界レベルSaaS基準ではまだ不足がある。

### Conclusion

条件付き合格。failure path E2E sliceとして採用するが、ISSUE-002はopen継続。

### Knowledge

Next.jsはroute announcerにも `role=alert` を使うため、E2Eでは実アプリの `section[role='alert']` にlocatorを限定する。

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 認証未実装のため対象外に近い | ISSUE-006で対応 |
| Tampering | transcriptに秘密情報や危険文字列を混入可能 | provider前scanでブロック |
| Repudiation | failed jobとして記録 | actor_id強化は未実装 |
| Information Disclosure | password / token patternをAI送信前に停止 | PII redactionは未実装 |
| Denial of Service | 長文/大量E2Eは未検証 | rate limit UI検証が必要 |
| Elevation of Privilege | 権限境界未実装 | ISSUE-006で再評価 |

## 検証結果

- `bundle exec rspec`: 24 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 3 passed
- `npm run api:verify`: 成功。OpenAPI contract warningなし。Node version warningのみ既知
- `npm audit --omit=dev`: 0 vulnerabilities

## 判定

条件付き合格。

Validation errorとsecret blockedのE2Eを追加し、失敗時の安全性は前進した。OpenAI upstream failure、live generation、Review Center統合が残るため、GitHub #2はopen継続。
