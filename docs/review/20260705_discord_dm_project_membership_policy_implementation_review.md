# Discord DM Project Membership / Policy Object 実装レビュー

## 評価日時

2026-07-05 15:56:37 JST

## 評価担当

Codex / Security Engineer / CTO / Backend Architect / Frontend Architect / QA / Product Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010

## 対象

- GitHub Issue: #30
- `ProjectMembership`
- `ConversationImportPolicy`
- DM import / summary draft API
- `docs/security/20260705_discord_dm_project_membership_policy.md`

## 良かった点

- `project_memberships` と `ConversationImportPolicy` を追加し、DM系APIでproject membershipを強制した。
- `owner/admin/editor/reviewer/viewer/auditor` のロールを操作別に分離した。
- `X-Actor-Id` を暫定actorとしてOpenAPIに定義し、Frontend API clientから送信するようにした。
- 認可失敗時は `conversation_import_forbidden` のsafe 403を返し、DM本文、タイトル、参加者、project名、role詳細を返さない。
- actor未指定時は401 `conversation_import_actor_required` を返し、AuditLogのactor_idにはDM操作実行者を保存するようにした。
- request specで他project member、非member、readonly member、承認権限なしを検証した。
- Project作成時に `X-Actor-Id` があればowner membershipを自動作成し、既存UIの初期導線を保った。

## 改善点

- `X-Actor-Id` は認証済みidentityではなく、productionではJWT/session等からactorを確定する必要がある。
- Project一覧、Meeting、Requirement、GitHub連携など他APIにはまだmembership認可が横展開されていない。
- membership管理APIがないため、owner以外のメンバー追加/変更はまだ運用手段がない。
- viewer/auditorはDM本文を読めるため、監査閲覧の範囲やmask-only viewは将来設計が必要。
- Frontendは権限不足を日本語表示できるが、role別にボタンを事前disableする権限メタデータは未提供。

## 優先順位

| 優先度 | 内容 | 状態 |
| --- | --- | --- |
| P0 | DM系APIのproject membership強制 | 完了 |
| P0 | 他project/非member/readonly/承認不可spec | 完了 |
| P0 | AuditLog actor_id接続 | 完了 |
| P1 | 実認証/JWTからactor idを確定 | ISSUE-006系で継続 |
| P1 | Project membership管理API | 次Issue候補 |
| P1 | 他APIへのPolicy横展開 | 次Issue候補 |
| P2 | role別UI disable/権限メタデータ | 次Issue候補 |

## 検証結果

- `bundle exec rails db:migrate`: success
- `bundle exec rspec spec/requests/api/v1/conversation_imports_spec.rb spec/requests/api/v1/conversation_summary_drafts_spec.rb spec/requests/api/v1/projects_spec.rb`: 25 examples, 0 failures
- `bundle exec rspec`: 175 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: success
- `npm run display:check`: success
- `npm run frontend:build`: success
- GitHub Actions CI `28732661801`: success（commit `80caf2c`）

補足: `npm run api:verify` で Node `v22.7.0` が期待範囲 `>=22.12.0 || >=20.19.0 <21.0.0` を満たさない警告とRedocly CLI更新通知が出たが、OpenAPI lintとtype生成は成功した。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM本文/整理結果へのAPIアクセスをproject membershipで制御する |
| Strategy | DM系APIへ限定してPolicy Objectを導入し、既存MVPの破壊範囲を抑える |
| Tactics | `project_memberships`、`ConversationImportPolicy`、safe 401/403、AuditLog actor、OpenAPI header、Frontend header |
| Assessment | Broken Access ControlのP0リスクは低下。実認証と横展開は残る |
| Conclusion | ISSUE-030は完了可能。実認証/JWT接続とmembership管理APIは後続課題 |
| Knowledge | OWASP A01、STRIDE、ISSUE-029/032のデータ保護方針 |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | `X-Actor-Id` は偽装可能 | MVP暫定。productionでは認証済みactorへ置換 |
| Tampering | viewer/reviewer/editorの権限外操作 | action別Policyとrequest specで拒否 |
| Repudiation | `system` 固定actor | DM操作ではactor_idをAuditLogへ保存 |
| Information Disclosure | 非member/他projectのDM閲覧 | read actionをmembership必須にした |
| Denial of Service | 権限不足者の匿名化 | owner/adminのみ許可 |
| Elevation of Privilege | editorが承認、viewerが更新 | specで拒否を検証 |

## OWASP Top 10

| 項目 | 評価 |
| --- | --- |
| A01 Broken Access Control | 改善。DM系APIでmembershipを強制 |
| A02 Cryptographic Failures | 暗号化済みデータのAPI漏えいを認可で補完 |
| A04 Insecure Design | role matrixとPolicy Objectを文書化/実装 |
| A09 Security Logging and Monitoring Failures | AuditLog actor接続で改善 |

## 次アクション

1. 次の推奨順としてProject membership管理APIまたは実認証/JWT接続をIssue化する。
2. DM以外のMeeting/Requirement/GitHub連携APIへPolicy Objectを横展開する。
3. role別UI disable/権限メタデータを設計する。

## Issue番号

- #30
