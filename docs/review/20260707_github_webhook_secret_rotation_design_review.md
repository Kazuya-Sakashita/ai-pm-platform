# 2026-07-07 GitHub Webhook secret rotation 設計レビュー

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

- `docs/issue/ISSUE-068_github_webhook_secret_rotation.md`
- `backend/app/services/github_integration/webhook_signature_verifier.rb`
- `docs/release/20260704_github_app_live_smoke_runbook.md`
- `docs/decisions/ADR-0021_github_webhook_secret_rotation.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- ADR

## 評価サマリー

GitHub Webhook secretは公開endpointのなりすまし防止に直結する。単一secretだけでは通常rotation時のdelivery dropが起きやすく、versioned keyringはGitHub signature headerにkey idがないため過剰である。MVP-to-betaではcurrent / previous secret方式が妥当である。

ただしprevious secretは攻撃可能期間を伸ばすため、通常rotationでは24時間以内に削除し、緊急rotationではprevious secretを使わない方針を明確にする必要がある。

## G-STACK評価

### Goal

GitHub Webhook secretを安全に交換し、通常rotationではdelivery dropを抑え、漏えい時は即時封じ込めを優先する。

### Strategy

実装はcurrent / previous secretの最小変更に留め、許容期間、rollback、監査証跡はADRとrunbookでrelease gateへ接続する。

### Tactics

- `GITHUB_WEBHOOK_SECRET` と `GITHUB_WEBHOOK_PREVIOUS_SECRET` を定義する。
- verifierは両方のsecretでHMACを計算し、どちらか一致すれば受理する。
- previous secretは通常rotationの一時互換だけに使う。
- secret値、signature、生payloadは保存しない。
- runbookに通常rotation、緊急rotation、rollback、証跡項目を追加する。

### Assessment

設計はISSUE-067のSecurity by Designを維持している。OpenAPI contractには影響がない。一方でprevious secret削除は運用依存なので、review evidenceとrelease gateで残留を検出する必要がある。

### Conclusion

実装へ進んでよい。完了条件はADR、verifier最小変更、RSpec、runbook、実装レビューを満たすこと。

### Knowledge

secret rotationは「秘密値を変える操作」ではなく、「安全な移行期間、失敗時のrollback、漏えい時の即時遮断、証跡」を一体で設計する運用機能である。

## STRIDE評価

| 脅威 | リスク | 対策 |
| --- | --- | --- |
| Spoofing | 漏えいした旧secretで署名される | previous secretは24時間以内に削除、緊急時は使わない |
| Tampering | rotation手順の順序ミスで正当deliveryを拒否 | current / previous併用期間を定義 |
| Repudiation | 誰がいつrotationしたか追えない | review/release evidenceへ承認者と時刻を保存 |
| Information Disclosure | secret値やsignatureを記録する | raw secret、signature、payload保存禁止 |
| Denial of Service | GitHub側とアプリ側のsecret不一致でdelivery停止 | rollback手順を定義 |
| Elevation of Privilege | previous secretが長期残留する | production完了条件にprevious secret削除確認を含める |

## 良かった点

- ISSUE-067の署名検証とsafe metadata方針を崩していない。
- versioned keyringより小さく、OpenAPI影響なしで実装できる。
- 通常rotationと緊急rotationを分けている。
- previous secretの削除期限を明示している。

## 改善点

- production deploy workflowでprevious secret残留を自動検出する仕組みは未実装である。
- GitHub live delivery smokeは実credentialと到達可能URLが必要で、本Issueでは未実施である。
- secret storeごとの具体手順は環境が確定してから追記が必要である。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | raw secret / raw signature非保存を維持 | 情報漏えい防止 |
| P0 | secret未設定時は検証前副作用なし | misconfiguration時の安全停止 |
| P1 | previous secret併用をRSpecで固定 | rotation中のdelivery drop抑制 |
| P1 | runbookへ通常/緊急/rollback手順を追記 | 運用再現性 |
| P1 | previous secret削除証跡を保存 | 長期残留防止 |

## 次アクション

1. ADR-0021を追加する。
2. `WebhookSignatureVerifier` をcurrent / previous secret対応にする。
3. request specとservice specを追加する。
4. live smoke runbookへrotation手順を追記する。
5. 実装レビューを保存する。

## 判定

条件付き合格。

実装、RSpec、runbook、実装レビューを追加すればISSUE-068は完了可能である。実GitHub delivery smokeはISSUE-004のrelease gateとして継続する。
