# 20260701_github_issue_publish_api_review

## 評価日時

2026-07-01 06:33 JST

## 評価担当

Codex as Product Manager, CTO, Tech Lead, Backend Architect, Frontend Architect, DevOps, Security Engineer, QA

## 使用フレームワーク

G-STACK、DDD、STRIDE、OWASP Top 10、ISO25010、RICE

## 評価対象

- ISSUE-004: GitHub Issue publish API / publish gate
- Backend: `GithubIssuePublishService`, `IssueDraftPublishGate`, `/issue-drafts/{id}/publish-github`
- Frontend: Issue Draft approval and GitHub publish controls
- Tests: RSpec service/request specs, Playwright E2E

## 良かった点

- Issue Draftが `approved`、OpenAPI Draftが `valid` / `approved`、OpenAPI Validator blockerが未解決でないことをpublish gateにした。
- GitHub連携未接続時は424で安全に停止し、`publish_failed`、Job、AuditLog、safe errorを残す。
- provider抽象を入れ、GitHub App実接続前でもfake/dry-run providerで成功ケースをrequest specで検証できる。
- publish成功時に `github_issue_number`、`github_issue_url`、repository、api id、node id、idempotency keyを保存する土台を追加した。
- FrontendにIssue Draft承認とPublish GitHub導線を追加し、未接続時のユーザー可視性をE2Eで確認している。

## 改善点

- GitHub App installation token providerは未実装で、実GitHub APIへのIssue作成はまだ有効化されていない。
- idempotency keyはDBへ保存するが、外部API成功後にDB保存が失敗した場合の完全復旧はまだ弱い。
- integration_accountsテーブルが未実装のため、接続状態、installation id、repository権限をDBで判定できない。
- publish APIのrate limit、permission denied、repo not foundなどのGitHub固有エラー分類はprovider実装待ち。
- Issue Draft変更後に `approved` を降格するルールが未決で、承認済み後の改変リスクが残る。
- Frontendのpublishボタンはgate状態を見てdisabledになるが、詳細なdisabled理由の表示はまだ弱い。

## 優先順位

1. P0: GitHub App providerを実装し、installation tokenで実Issue作成する。
2. P0: integration_accountsを実装し、接続状態とrepository権限をDBで判定する。
3. P0: publish idempotencyの復旧戦略を強化する。
4. P0: Issue Draft / OpenAPI Draftのcontent変更時にapprovalを降格するADRを作る。
5. P1: Frontendにpublish disabled理由を明示する。
6. P1: GitHub固有エラーのsafe mappingとretry/backoffを実装する。

## 次アクション

- ISSUE-004は継続OPEN。次はGitHub App providerとintegration_accounts実装を進める。
- GitHub App実接続前に、`docs/security/` のsecret保管、token非ログ化、permission最小化を再確認する。
- provider実装後に実リポジトリへのdry-run/本番作成を切り替える運用フラグを追加する。

## 検証結果

- `bundle exec rspec`: 70 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: OpenAPI OK、Redocly lint OK、型生成OK
- `npm run frontend:build`: success
- `npm run frontend:e2e`: 6 passed
- `npm audit --omit=dev`: 0 vulnerabilities

## Issue番号

ISSUE-004

GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/4
