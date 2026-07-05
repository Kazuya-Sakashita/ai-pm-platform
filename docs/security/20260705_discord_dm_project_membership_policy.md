# Discord DM Project Membership / Policy

## 作成日

2026-07-05

## 対象Issue

- GitHub Issue: #30
- ローカルIssue: `docs/issue/ISSUE-030_discord_dm_project_membership_policy.md`

## 方針

Discord DMインポートは高センシティブデータを扱うため、暗号化だけでなくAPI操作時のproject membership認可を必須にする。MVPでは実認証基盤が未接続のため、`X-Actor-Id` ヘッダーを暫定actor identityとして扱い、将来の認証済みuser idへ置き換え可能な形にする。

`X-Actor-Id` は認証そのものではない。productionではJWT/sessionなどの認証結果からactor idを確定し、ヘッダーを信頼しない構成へ移行する。本IssueではPolicy Object、DB membership、safe 403、AuditLog actor接続を先に固定する。

## ロール

| ロール | 用途 |
| --- | --- |
| `owner` | project所有者。DM匿名化を含む全操作が可能 |
| `admin` | project管理者。DM匿名化を含む全操作が可能 |
| `editor` | DMインポート作成、編集、安全チェック、AI整理、整理ドラフト編集が可能。承認と匿名化は不可 |
| `reviewer` | DM閲覧、整理ドラフト編集、承認が可能。DM原文更新、AI生成、匿名化は不可 |
| `viewer` | DM閲覧のみ |
| `auditor` | DM閲覧のみ。監査目的の読み取りを想定 |

## 操作別権限表

| 操作 | endpoint | owner | admin | editor | reviewer | viewer | auditor | 非member |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 一覧/閲覧 | `GET /projects/{project_id}/conversation-imports`, `GET /conversation-imports/{id}` | allow | allow | allow | allow | allow | allow | deny |
| 作成 | `POST /projects/{project_id}/conversation-imports` | allow | allow | allow | deny | deny | deny | deny |
| 更新 | `PATCH /conversation-imports/{id}` | allow | allow | allow | deny | deny | deny | deny |
| 安全チェック | `POST /conversation-imports/{id}/scan` | allow | allow | allow | deny | deny | deny | deny |
| AI整理生成 | `POST /conversation-imports/{id}/generate-summary` | allow | allow | allow | deny | deny | deny | deny |
| 匿名化 | `DELETE /conversation-imports/{id}` | allow | allow | deny | deny | deny | deny | deny |
| 整理ドラフト閲覧 | `GET /conversation-summary-drafts/{id}` | allow | allow | allow | allow | allow | allow | deny |
| 整理ドラフト編集 | `PATCH /conversation-summary-drafts/{id}` | allow | allow | allow | allow | deny | deny | deny |
| 整理ドラフト承認 | `POST /conversation-summary-drafts/{id}/approve` | allow | allow | deny | allow | deny | deny | deny |

## Safe Error

認可失敗時は本文、project名、DMタイトル、参加者、role詳細を返さない。

```json
{
  "error": {
    "code": "conversation_import_forbidden",
    "message": "Conversation import access is forbidden.",
    "details": {
      "action": "read"
    }
  },
  "request_id": "..."
}
```

actor未指定時は401で `conversation_import_actor_required` を返す。非memberまたは権限不足は403で `conversation_import_forbidden` を返す。

## AuditLog

DM関連の作成、更新、安全チェック、AI整理、承認、匿名化は `actor_id` に `X-Actor-Id` を保存する。retention jobなどシステム操作は引き続き `system` を使う。

## 残リスク

- `X-Actor-Id` は暫定identityであり、production認証の代替ではない。
- Project以外のMeeting/Requirement/GitHub連携APIにはまだ横展開していない。
- Project一覧は現時点では絞り込まないため、project metadata露出の本格対策は認証基盤導入時に必要。

## 次アクション

1. `project_memberships` テーブル、model、factoryを追加する。
2. `ConversationImportPolicy` を実装する。
3. DM関連controllerでactor必須化とPolicy Object認可を行う。
4. request specで他project、非member、readonly、承認権限なしを検証する。
5. OpenAPIとFrontend clientに `X-Actor-Id` を反映する。
