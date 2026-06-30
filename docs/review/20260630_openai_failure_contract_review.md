# 2026-06-30 OpenAI Failure Contract レビュー

## 評価日時

2026-06-30 12:17 JST

## 評価担当

Codex as AI Architect / Backend Architect / Frontend Architect / QA / Security Engineer / Tech Lead

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## 良かった点

- OpenAI APIのrate limitを429として扱い、UIとAPI clientがリトライ可能な失敗として判別できるようにした。
- OpenAI upstream failure、invalid AI response、rate limitのFrontend表示をPlaywrightで検証対象に追加した。
- Backend request specでprovider failure時のfailed job、safe error、request_id付きaudit metadataを確認した。
- API schemaを増やさず、既存のerror/details/job contractで失敗可視化を実現した。
- 外部OpenAI通信に依存しないため、CI再現性を維持できる。

## 改善点

- FrontendのOpenAI失敗系E2EはAPI route mockであり、実OpenAI providerからcontrollerまでの完全なfull-stack E2Eではない。
- rate limit時のUIはメッセージ表示のみで、再試行ボタン、待機時間、backoff guidanceがない。
- invalid AI response発生時に、ユーザー向けの復旧導線と開発者向けの診断導線が分離されていない。
- provider別の失敗分類はまだ最小限で、timeout、network failure、quota、auth failureのUX差分が不足している。
- GitHub ActionsのNode 20 deprecation annotationが残っている。

## 優先順位

1. P0: 本番OpenAI API keyでlive generation smoke testを実施する
2. P0: Review Center本体との統合E2Eを追加する
3. P1: rate limit時のRetry UIとbackoff policyを設計する
4. P1: timeout / auth / quota failureの分類とUI表示を追加する
5. P1: CI actionのNode 24対応を明示してdeprecation annotationを解消する

## 次アクション

- RSpec、Frontend build、Playwright E2E、OpenAPI verifyを実行し、GitHubへpushする。
- CI成功後、Issue #2へ結果を同期する。
- live OpenAI smokeが未実施のため、Issue #2はopen継続。

## Issue番号

- GitHub Issue: #2

## G-STACK

### Goal

AI生成が失敗した場合でも、ユーザーが安全なエラー内容とfailed job状態を確認でき、監査ログに原因を残せるようにする。

### Strategy

OpenAI依存の実通信はCIから外し、Backend contract specとFrontend failure mock E2Eを組み合わせて失敗時の契約を固定する。

### Tactics

- OpenAI providerの429 mappingを追加
- provider failure request specを追加
- PlaywrightでOpenAI upstream failure、invalid AI response、rate limitのUI表示を検証
- Issue台帳とレビュー文書を更新

### Assessment

失敗契約の網羅性は改善したが、実OpenAI live smokeとRetry UXがないため、世界レベルSaaS基準ではまだ改善余地が大きい。

### Conclusion

条件付き合格。CI再現性を保ったまま失敗系を広げた点は有効。ただしIssue #2の完了にはlive smokeとReview Center統合が必要。

### Knowledge

外部AI連携のE2Eは、full-stack実通信、provider contract spec、Frontend API contract mockを分けると、CI安定性とUX保証を両立しやすい。

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | request_idはprovider由来でありユーザー認証とは未接続 | ISSUE-006で認証/監査actorを強化 |
| Tampering | 不正なAI応答はinvalid_ai_responseとして処理 | schema normalization specで確認 |
| Repudiation | failed jobとaudit metadataにprovider error code/request_idを保存 | request specで確認 |
| Information Disclosure | safe_detailのみUIへ表示 | raw provider errorの露出を避ける |
| Denial of Service | rate limitを429として扱う | Retry/backoff UIは未実装 |
| Elevation of Privilege | 権限境界は未実装 | ISSUE-006で対応 |

## 検証結果

- `bundle exec rspec`: 27 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run frontend:build`: 成功
- `npm run frontend:e2e`: 6 passed
- `npm run api:verify`: 成功。OpenAPI contract warningなし。Node version warningのみ既知
- `npm audit --omit=dev`: 0 vulnerabilities

## 判定

条件付き合格。OpenAI failure contract sliceとして採用する。ただしlive OpenAI smokeとReview Center統合が未完了のため、Issue #2はopen継続。
