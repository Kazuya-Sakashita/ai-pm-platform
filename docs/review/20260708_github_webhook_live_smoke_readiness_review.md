# 2026-07-08 GitHub Webhook live smoke readiness review

## 評価日時

2026-07-08 07:43:01 JST

## 評価担当

Codex / Security Engineer / DevOps / QA / Tech Lead

## Issue番号

ISSUE-004 / GitHub Issue #4

## 対象

- `scripts/github-webhook-live-smoke.rb`
- `docs/release/20260704_github_app_live_smoke_runbook.md`
- GitHub App webhook設定のreadiness確認

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- DORA Metrics

## 評価サマリー

GitHub App webhook live delivery smokeへ進む前段として、GitHub App管理APIからwebhook設定と直近deliveryを確認する安全なsmoke scriptを追加した。scriptはGitHub App JWTを生成して `/app/hook/config` と `/app/hook/deliveries` を確認するが、raw webhook secret、signature、payload、GitHub delivery id生値は出力しない。証跡はdelivery digest、event、action、HTTP status、safe failure codeに限定する。

実行結果として、App IDとprivate keyは設定済みだが、ローカルruntimeの `GITHUB_WEBHOOK_SECRET` は未設定だった。またGitHub App側のwebhook URLはplaceholderで、直近deliveryは502だった。そのためGitHub webhook live delivery smokeは未完了と判定する。

## 良かった点

- secretやraw payloadを出さずに、GitHub App webhook設定とdelivery履歴を確認できるようになった。
- placeholder URL、webhook secret未設定、直近delivery失敗を `safe_failures` として機械判定できるようになった。
- delivery id生値ではなくSHA-256 digestだけを証跡化する方針を守れている。
- live delivery未完了の理由が、実装不足ではなく環境設定不足として明確になった。
- runbookにwebhook live delivery手順、失敗条件、保存してよい証跡を追記できた。

## 改善点

- GitHub App webhook URLがowned staging / production URLではなくplaceholderのため、GitHubからアプリへ到達できない。
- `GITHUB_WEBHOOK_SECRET` がローカルruntimeに未設定で、実deliveryを受けても署名検証できない。
- 直近deliveryが502で失敗しており、GitHub App側のdelivery再送または設定更新後の再triggerが必要である。
- 現時点ではGitHub delivery履歴とローカルDBの `GithubWebhookDelivery` / `AuditLog` を自動照合していない。
- staging / production公開URLがないため、production相当のupstream body size / rate limit確認までは未実施である。

## 改善案

1. GitHub App settingsでWebhook URLをowned staging / production URLの `/api/v1/webhooks/github` に変更する。
2. GitHub App settingsのWebhook secretと同じ値をsecret storeまたは `.env` の `GITHUB_WEBHOOK_SECRET` に設定する。
3. `scripts/github-webhook-live-smoke.rb --limit 5` を再実行し、`safe_failures` が空になることを確認する。
4. GitHub Appのrepository selection updateまたはpermissions acceptanceでdeliveryを再triggerする。
5. Rails側で `GithubWebhookDelivery` と `github.webhook.installation_sync` AuditLogを確認し、digestだけをレビューへ保存する。
6. 後続でDB照合まで行うscriptまたはRails runner taskを追加する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | Webhook URLをreachable endpointへ変更 | 現在はGitHubから到達できずdeliveryが502 |
| P0 | `GITHUB_WEBHOOK_SECRET` をruntimeへ設定 | 署名検証の信頼境界であり未設定では受信不可 |
| P1 | delivery再送または再trigger | 成功delivery証跡がないとISSUE-004を閉じられない |
| P1 | DB / AuditLog照合 | GitHub側成功だけではアプリ側同期成功を証明できない |
| P2 | staging / production upstream guard証跡 | 公開前のDoS耐性確認に必要 |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | GitHub App webhook live delivery smokeを安全に実施できる状態へ近づける |
| Strategy | secret非出力のreadiness scriptで、環境設定不足とdelivery失敗を先に切り分ける |
| Tactics | `/app/hook/config` と `/app/hook/deliveries` をGitHub App JWTで確認し、safe JSONだけを出力する |
| Assessment | 実行可能な診断は整ったが、現在の環境はplaceholder URL、secret未設定、502 deliveryのため未合格 |
| Conclusion | scriptとrunbookは採用。ただしlive delivery smokeは環境設定後に再実行する |
| Knowledge | raw delivery id、signature、payload、secretを証跡に残さない方針は維持する |

## STRIDE / OWASP観点

- Spoofing: `GITHUB_WEBHOOK_SECRET` 未設定は署名検証不能につながるためP0。
- Tampering: raw payloadを保存しない設計はよいが、受信成功後のDB照合が必要。
- Repudiation: GitHub delivery履歴だけでなく、`GithubWebhookDelivery` とAuditLogを残す必要がある。
- Information Disclosure: scriptはsecret、signature、payload、raw delivery idを出力しないため方針に合う。
- Denial of Service: staging / production upstream guardは未確認で、ISSUE-004後続として残る。
- OWASP A05 Security Misconfiguration: placeholder URLとruntime secret未設定は公開前blocker。

## 検証結果

- `ruby -c scripts/github-webhook-live-smoke.rb`: Syntax OK
- `.env` 読込後の `ruby scripts/github-webhook-live-smoke.rb --limit 5`: exit 1
- safe failures:
  - `github_webhook_secret_missing`
  - `github_webhook_url_placeholder`
  - `github_webhook_recent_delivery_failed`

保存していない情報:

- raw webhook secret
- `X-Hub-Signature-256`
- raw payload
- raw GitHub delivery id
- GitHub App private key

## 次アクション

1. GitHub App settingsでWebhook URLをowned endpointへ変更する。
2. `GITHUB_WEBHOOK_SECRET` をruntimeへ設定する。
3. GitHub deliveryを再triggerまたはredeliverし、2xx deliveryを確認する。
4. `GithubWebhookDelivery` とAuditLogのsafe evidenceを確認する。
5. 成功結果を `docs/review/YYYYMMDD_github_webhook_live_delivery_review.md` に保存する。

## 結論

GitHub webhook live delivery smokeへ進むための安全な診断土台はできた。ただし現時点の結果は未合格であり、ISSUE-004は継続OPENとする。世界レベルSaaS基準では、webhook URL、secret、delivery成功、DB/AuditLog同期、upstream guard証跡が揃うまで完了扱いにしない。
