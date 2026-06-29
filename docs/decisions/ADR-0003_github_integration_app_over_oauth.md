# ADR-0003: MVPのGitHub連携はOAuth AppではなくGitHub Appを採用する

## Status

Accepted

## Date

2026-06-30

## Context

AI PM Platformは、会議ログから生成したIssue DraftをGitHub Issueとして公開する。将来はPull Request、レビュー、Actions、release noteへの拡張も想定する。

GitHub連携方式として、主にGitHub AppとOAuth Appがある。MVPでは、最小権限、リポジトリ単位のインストール、監査、token保管、将来拡張を重視する必要がある。

## Decision

MVPではGitHub Appを採用する。OAuth Appは採用しない。

GitHub Appのinstallation access tokenを使い、ユーザーの個人権限ではなく、インストールされたリポジトリへのアプリ権限でIssueを作成する。

## Rationale

GitHub公式ドキュメントでは、一般にGitHub Appを優先し、OAuth Appはユーザーとして振る舞う必要がある場合に使うべきと説明されている。GitHub Appは細かい権限、リポジトリ単位のアクセス、短命token、Webhook連携に適している。

本プロダクトのMVPは「ユーザー本人としてGitHub全体を操作する」より、「特定リポジトリにAI PMがIssueを作成する」ことが主目的である。そのためGitHub Appのモデルが合う。

## Required Permissions

MVPで必要なGitHub App権限は以下に限定する。

| Permission | Access | Reason |
| --- | --- | --- |
| Issues | Read and write | Approved Issue DraftをGitHub Issueとして作成する |
| Metadata | Read-only | GitHub Appに必須の基本情報参照 |

初期MVPでは以下を要求しない。

- Contents
- Pull requests
- Actions
- Checks
- Administration
- Secrets
- Webhooks beyond app installation events

将来OpenAPIやコード生成、PR作成、CI確認を行う場合は、別IssueとADRで権限追加をレビューする。

## Data Storage

保存する:

- github_app_installation_id
- repository_owner
- repository_name
- granted_permissions
- installation_status
- last_sync_at
- last_error_safe

保存しない:

- installation access tokenの平文
- OAuth code
- webhook secretの平文
- GitHub API raw error全文

短命installation access tokenは、必要時に生成し、可能な限り永続保存しない。やむを得ず保存する場合は暗号化し、有効期限とrotationを必須にする。

## Issue Publish Boundary

GitHub Issue公開は以下をすべて満たす場合のみ許可する。

- Issue Draft status is approved
- Review blocker P0 is zero
- GitHub App installation is active
- Repository matches the project configuration
- Secret scan status is clear or warning accepted
- Idempotency-Key is present for retry-prone operations

## Disconnect Policy

Disconnect時に行うこと:

- installation statusをrevokedまたはdisconnectedにする
- 保存済みtokenがあれば削除する
- GitHub publishを停止する
- unsynced issue draftsはローカルに残す
- audit_logsへdisconnect操作を記録する

Disconnectしても、過去に作成済みのGitHub Issueは削除しない。

## Webhook Policy

Webhookを受ける場合は署名検証を必須にする。署名検証に失敗したpayloadは保存しない。

MVPで必須のWebhook:

- installation created
- installation deleted or suspended
- repository access changed

## Consequences

良い点:

- 最小権限にしやすい。
- リポジトリ単位で導入できる。
- ユーザー個人tokenへの依存が減る。
- 将来のPR、Actions、Checks連携に拡張しやすい。
- token漏洩時の影響範囲を限定しやすい。

悪い点:

- GitHub App作成とinstallation flowが必要になる。
- OAuth Appより初期実装は少し複雑。
- ユーザー本人としての操作が必要な機能には追加設計が必要。

## Alternatives

### OAuth App

不採用。

理由:

- ユーザー権限に引きずられやすい。
- repo scopeなどが広くなりやすい。
- 特定リポジトリにAI PMをインストールするMVP体験とずれる。

### Personal Access Token

不採用。

理由:

- SaaSとしてユーザーにPATを入力させる体験はセキュリティとUXの両面で弱い。
- token rotation、scope、監査が難しい。

## References

- GitHub Docs: Differences between GitHub Apps and OAuth apps: https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/differences-between-github-apps-and-oauth-apps
- GitHub Docs: Choosing permissions for a GitHub App: https://docs.github.com/en/apps/creating-github-apps/setting-up-a-github-app/choosing-permissions-for-a-github-app
- GitHub REST API: Issues: https://docs.github.com/en/rest/issues/issues
- GitHub Docs: Validating webhook deliveries: https://docs.github.com/en/webhooks/using-webhooks/validating-webhook-deliveries

## Follow-up

- GitHub App manifestまたは手動作成手順を作る。
- GitHub installation callback APIのpayload詳細をOpenAPIへ追加する。
- installation access token生成とキャッシュ方針をBackend設計へ落とす。

