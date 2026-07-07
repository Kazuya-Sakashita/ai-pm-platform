# 2026-07-07 GitHub Webhook secret rotation 実装レビュー

## 評価日時

2026-07-07 21:03:24 JST

## 評価担当

Codex L1ロール分離レビュー

- Security Engineer
- DevOps
- Backend Architect
- QA

外部AIレビュー: 未実施。Claude / ChatGPT等の外部AIレビューは追加待ち。

## Issue番号

ISSUE-068 / GitHub Issue #108

## 対象成果物

- `docs/decisions/ADR-0021_github_webhook_secret_rotation.md`
- `docs/release/20260704_github_app_live_smoke_runbook.md`
- `backend/app/services/github_integration/webhook_signature_verifier.rb`
- `backend/spec/services/github_integration/webhook_signature_verifier_spec.rb`
- `backend/spec/requests/api/v1/webhooks_spec.rb`
- `docs/issue/ISSUE-068_github_webhook_secret_rotation.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA回帰テスト

## 評価サマリー

GitHub Webhook secret rotation方針としてADR-0021を追加し、MVP-to-betaではcurrent / previous secret方式を採用した。`WebhookSignatureVerifier` は `GITHUB_WEBHOOK_SECRET` と `GITHUB_WEBHOOK_PREVIOUS_SECRET` の両方を検証できるようになり、通常rotation window中は旧secret署名deliveryも受理できる。

runbookには通常rotation、緊急rotation、rollback、証跡項目を追記した。緊急rotationではprevious secretを使わず、漏えい疑い時の封じ込めを優先する。secret未設定時は検証前副作用なしで401を返す既存挙動を維持した。

## G-STACK評価

### Goal

GitHub Webhook secretを安全に交換し、delivery dropと漏えい時リスクの両方を抑える。

### Strategy

OpenAPIやDBを増やさず、署名検証Serviceだけを最小変更する。運用上の許容期間、rollback、証跡はADRとrunbookで管理する。

### Tactics

- `GITHUB_WEBHOOK_PREVIOUS_SECRET` をrotation window用に追加した。
- current / previous secretを重複排除して検証する。
- previous secret署名をService specとRequest specで確認した。
- secret未設定時にprevious secretもnilなら安全に失敗することを確認した。
- runbookにprevious secret削除期限とevidence項目を追加した。

### Assessment

署名検証の柔軟性は上がったが、previous secret削除は運用ゲートに依存する。ADRで24時間以内の削除とproduction完了条件を定義したため、release evidenceで監査する必要がある。

### Conclusion

実装は合格。CI確認後にIssue #108をクローズしてよい。実GitHub live deliveryでのrotation smokeはISSUE-004のrelease gateとして継続する。

### Knowledge

rotationの安全性は、コードが複数secretを受けることだけでは決まらない。いつ旧secretを消すか、失敗時に戻せるか、漏えい時に旧secretを許容しないかが重要である。

## 良かった点

- OpenAPIやDB contractに影響を出さず、署名検証だけを拡張した。
- secret未設定時の安全停止を維持した。
- previous secret署名の受理をRequest specで確認した。
- 通常rotationと緊急rotationをADRとrunbookで分けた。
- raw secret、signature、payload、delivery id生値を保存しない方針を維持した。

## 改善点

- previous secretの削除を自動検出するCI/CD gateは未実装である。
- 実GitHub App webhook deliveryでのrotation smokeは未実施である。
- secret store固有の手順はまだ抽象的である。
- deliveryごとのmatched secret slotは保存していないため、詳細分析はrelease evidenceに依存する。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | GitHub Actions `verify` 成功確認 | main反映前の品質ゲート |
| P1 | ISSUE-004でlive rotation smokeを実施 | 実GitHub deliveryで確認するため |
| P1 | previous secret残留チェックのCI/CD化を検討 | 運用ミス防止 |
| P2 | secret store固有手順を追記 | production導入時の再現性向上 |

## 次アクション

1. PRを作成し、GitHub Actions `verify` を確認する。
2. CI成功後にGitHub Issue #108をクローズする。
3. ISSUE-004のlive smokeでwebhook secret rotation evidenceを取得する。
4. ISSUE-069でpayload size / rate limit guardを進める。

## 検証結果

- `bundle exec rspec spec/services/github_integration/webhook_signature_verifier_spec.rb spec/requests/api/v1/webhooks_spec.rb`: 15 examples, 0 failures
- `bundle exec rspec`: 390 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run display:check`: Display labels OK
- `git diff --check`: success

## AIレビュー比較

Codex一次レビューのみ。外部AIレビューは未実施。外部レビュー結果が追加された場合は、previous secret許容期間、emergency rotation時のprevious secret禁止、raw secret非保存、release evidence項目を重点比較する。

## Rails責務分離

- Controller: 変更なし。Webhook受信とresponseに限定したまま。
- Service: `WebhookSignatureVerifier` にcurrent / previous secret検証を閉じた。
- Model: 変更なし。secretやsignatureは保存しない。
- 過剰設計回避: GitHub signature headerにkey idがないため、versioned keyringは採用しなかった。
- テスト方針: Service specとRequest specでcurrent / previous / invalid / missing secretを固定した。

## 判定

条件付き合格。

ローカル検証とGitHub Actions `verify` が通れば完了可能である。実credentialでのrotation smokeはISSUE-004で扱う。
