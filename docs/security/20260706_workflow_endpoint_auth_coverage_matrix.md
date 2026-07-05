# ワークフローエンドポイント認可カバレッジ表

## 目的

ISSUE-048として、既存ワークフローエンドポイントの認証/認可カバレッジを統一する。ProjectMembershipをproduction APIのproject authorization境界とし、未認証、非member、role不足、cross-project accessをrequest specで検証する。

## ロール方針

| 操作 | 必要role | 理由 |
| --- | --- | --- |
| Project範囲の閲覧 | owner, admin, editor, reviewer, viewer, auditor | project内情報の閲覧と監査 |
| Meeting作成 | owner, admin, editor | 会議ログ投入はproject data作成 |
| ワークフロー生成 | owner, admin, editor | AI生成/job作成はコストと情報処理を伴う |
| Draft更新 | owner, admin, editor | 議事録/要件/API/Issue draftの内容変更 |
| 承認/レビュー解決 | owner, admin, reviewer | 人間レビューgateの解除 |
| GitHub公開/照合 | owner, admin | 外部副作用と公開操作 |
| Integration接続/解除 | owner, admin | 外部連携設定変更 |
| Job閲覧 | owner, admin, editor, reviewer, viewer | project内job状態の閲覧 |
| Operations queue health閲覧 | owner, admin | 運用情報のため管理者限定 |
| GitHub callback | signed state | GitHubからのcallbackでありBearer authではなくstate検証を信頼境界にする |

## カバレッジ表

| Controller | Endpoint group | Project境界 | 現状 | 対応方針 |
| --- | --- | --- | --- | --- |
| Meetings | list/create/show | `project_id` or meeting.project | 未認証で閲覧/作成可能 | read/create roleで保護 |
| Minutes | generate/show/update/approve | minute.meeting.project / meeting.project | 未認証で生成/閲覧/更新/承認可能 | generate/updateはeditor以上、approveはreviewer以上、showはread |
| Requirements | generate/show/update/approve | requirement.minute.meeting.project | 未認証で生成/閲覧/更新/承認可能 | generate/updateはeditor以上、approveはreviewer以上、showはread |
| IssueDrafts | generate/show/update/publish/reconcile/manual resolve | issue_draft.requirement.minute.meeting.project | 未認証でGitHub publish/reconcileまで可能 | generate/updateはeditor以上、publish/reconcileはadmin以上、showはread |
| OpenApiDrafts | generate/show/update/validate | open_api_draft.requirement.minute.meeting.project | 未認証で生成/閲覧/更新/validate可能 | generate/update/validateはeditor以上、showはread |
| Integrations | list/connect/disconnect | `project_id` | 未認証でlist/connect/disconnect可能、callbackはstate検証 | listはread、connect/disconnectはadmin以上、callbackはstate検証維持 |
| Reviews | list/create/resolve/accept risk | target resourceからproject推定、またはproject_id | global list/createが未認証 | target projectのread/create/resolve roleで保護。project不明targetは明示的project_id必須 |
| Jobs | show | job.project | 未認証でjob閲覧可能 | read roleで保護 |
| Operations | queue-health | global operations | 未認証で運用情報閲覧可能 | owner/adminのみ許可。project_id指定を必須にする |

## OpenAPI契約

- 保護対象のワークフローエンドポイントにはbearer securityを定義する。
- 保護対象のワークフローエンドポイントには `Unauthorized` と `Forbidden` を定義する。
- GitHub callbackはone-time signed stateで保護し、不正または再利用されたstateでは `github_state_invalid` を返す。

## Frontend影響

- 既存のfrontend request helperは401 terminal auth errorsを処理済みである。
- 403は既存のAPI error surface経由で安全な日本語エラー表示を維持する。
- Operations queue healthの新しい `project_id` 必須化に合わせ、UIのrequest pathを更新する。

## 非スコープ

- Organization-wide RBAC
- SSO/SAML/SCIM
- Billing/plan entitlements
- Replacing GitHub callback state trust with user Bearer auth
