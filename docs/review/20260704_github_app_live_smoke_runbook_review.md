# GitHub App Live Smoke Runbook Review

## 評価日時

2026-07-04 08:13 JST

## 評価担当

Codex / Product Manager / CTO / DevOps / Security Engineer / QA / Tech Lead

外部AIレビュー: 未実施。Claude、ChatGPT等の外部レビューは環境から直接実行できないため、Codex一次レビューとして保存する。

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DORA Metrics

## Issue番号

- ISSUE-004
- GitHub Issue #4

## 良かった点

- GitHub App credentialを使うlive smokeの前提、手順、合否基準、保存すべき証跡を `docs/release/` に分離した。
- connect、publish、marker search reconciliation、manual link、controlled retryの各経路を1つのrunbookで追えるようにした。
- 秘密情報をdocsやAI chatへ貼らない方針、`GITHUB_APP_PRIVATE_KEY_BASE64` 推奨、token/private key非ログ化確認を明記した。
- `incomplete_results=true` の自動reconcile禁止、URL/番号不一致拒否、controlled retry承認者/理由必須など、既存の安全実装をlive smokeの検証観点へ接続した。
- Issue #4のクローズ条件に必要な証跡、commit SHA、Issue Draft、attempt、AuditLog、作成GitHub Issue URLを明文化した。

## 改善点

- 実credentialはまだ設定されておらず、runbookは未実行である。
- GitHub webhook delivery、installation revoked、permissions changed同期のlive smokeは対象外であり、別Issueまたは後続runbookが必要。
- UI操作を前提にしており、完全自動のlive smoke testではない。
- 認証/認可が未実装のため、connection startやcontrolled retryの実ユーザー主体はまだ監査できない。
- secret scanやlog redactionの自動検査はrunbook上の確認に留まっている。

## 優先順位

- P0: credential設定後、runbookどおりconnect/publish/reconcile smokeを実行する。
- P0: smoke結果を `docs/review/YYYYMMDD_github_app_live_smoke_review.md` として保存する。
- P1: webhook deliveryとinstallation revoked/permissions changed同期のrunbookを追加する。
- P1: live smokeの一部を自動化し、作成Issueをテスト用repositoryへ限定する。
- P1: 認証導入後、actorとapproverを実ユーザーIDへ紐付ける。

## 次アクション

- GitHub Issue #4へrunbook追加を同期する。
- credentialが準備できたらrunbookを実行し、成功/失敗証跡をレビューとして保存する。
- live smoke成功まではISSUE-004をopen維持する。

## G-STACK

### Goal

Issue #4を完了判定できるように、実GitHub App credentialで検証すべき経路と証跡を明確にする。

### Strategy

実credentialがなくても先にrunbookを整備し、credential取得後の手戻りと危険な手作業を減らす。

### Tactics

- `docs/release/20260704_github_app_live_smoke_runbook.md` を追加する。
- secret handling、preconditions、smoke steps、failure handling、evidence、completion criteriaを分けて記録する。
- `docs/release/README.md` からrunbookへ到達できるようにする。

### Assessment

運用準備としては前進。ただし実行結果がないため、世界レベルSaaS基準ではIssue #4のクローズ根拠にはまだ不足する。

### Conclusion

Runbook作成は完了。次はcredential設定後のlive smoke実行とレビュー保存が必須。

### Knowledge

既存のGitHub App provider、integration account、publish attempt、reconciliation、manual link、controlled retryの実装成果を、運用検証手順へ接続した。
