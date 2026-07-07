# Discord連携権限境界と段階導入方針

## 作成日

2026-07-07

## 対象Issue

- ISSUE-006
- GitHub Issue: #6

## 目的

ISSUE-006の完了条件である「Discord連携の権限」を、MVPの手動インポート、将来のBot連携、将来のOAuth連携に分けて定義する。

## 公式仕様確認

- Discord OAuth2 scope一覧では、`dm_channels.read` は承認済みパートナー向けscopeである。
- Discord OAuth2ではCSRF対策として `state` パラメータの実装が推奨されている。
- Discord Bot userは標準ユーザーアカウントとは異なり、friendやGroup DMへの参加ができない。
- Discord BotのOAuth2 authorizationでは `bot` scopeと要求permissionsを指定する。

参照:

- https://docs.discord.com/developers/topics/oauth2
- https://docs.discord.com/developers/events/gateway
- https://docs.discord.com/developers/resources/channel

## 現在のMVP方針

MVPではDiscord APIからDMを自動取得しない。ユーザーが明示的に貼り付けた `discord_dm_paste` だけを対象にする。

この方針により、Discord側で要求する権限はゼロにする。代わりに、アプリ内で以下を必須にする。

- project membershipによる閲覧、作成、編集、AI整理、承認、匿名化の認可
- 同意確認
- redaction
- secret / PII scan
- redacted text優先のAI送信
- Review gate
- AuditLog
- retention / anonymization

## Discord連携方式別の許可方針

| 方式 | MVP採用 | 要求scope / permission | 許可条件 | 禁止事項 |
| --- | --- | --- | --- | --- |
| 手動DM貼り付け | 採用 | Discord側scopeなし | project memberが同意確認とredactionを行う | Discord API自動取得、self-bot、全量同期 |
| BotとのDM | 将来候補 | `bot` scope。必要permissionは機能ごとにADRで追加 | Bot本人とのDMだけを対象にし、人同士のDM代替として扱わない | Group DM参加前提、ユーザーDM履歴の取得 |
| Guild channel Bot | 将来候補 | `bot`、`applications.commands`、最小channel permission | 管理者が対象guild/channelを明示し、message content扱いを別途レビュー | guild全体の無差別収集、広い管理権限 |
| Discord OAuth user連携 | 将来候補 | 初期候補は `identify` のみ。追加scopeはADR必須 | state検証、token暗号化、scope差分レビューを必須 | `dm_channels.read` 前提のMVP実装、未承認scope利用 |
| Approved partner DM取得 | 非スコープ | `dm_channels.read` 等 | Discord承認、法務、同意、DPIA相当レビュー後のみ | 現MVPでの実装、暗黙同意での取得 |
| self-bot / user automation | 禁止 | なし | 許可しない | ユーザーアカウント自動操作、DOM scraping |

## アプリ内権限

Discord由来データはDiscord側scopeではなく、AI PM Platform内のproject membershipを信頼境界にする。

| 操作 | 許可ロール | 既存証跡 |
| --- | --- | --- |
| DMインポート閲覧 | owner, admin, editor, reviewer, viewer, auditor | `docs/security/20260705_discord_dm_project_membership_policy.md` |
| DMインポート作成、編集、安全チェック、AI整理生成 | owner, admin, editor | `docs/security/20260705_discord_dm_project_membership_policy.md` |
| DM整理ドラフト編集 | owner, admin, editor, reviewer | `docs/security/20260705_discord_dm_project_membership_policy.md` |
| DM整理ドラフト承認 | owner, admin, reviewer | `docs/security/20260705_discord_dm_project_membership_policy.md` |
| DM匿名化 | owner, admin | `docs/security/20260705_discord_dm_project_membership_policy.md` |

## Token保存方針

MVPではDiscord OAuth tokenを保存しない。

将来Discord OAuthまたはBot連携を追加する場合は、以下を必須にする。

- access token / refresh token / bot tokenは平文保存しない。
- Rails Active Record EncryptionまたはKMS管理のsecret storeに保存する。
- tokenのscope、expires_at、revoked_at、last_used_atを保持する。
- token raw value、OAuth code、Authorization header、callback payload全文をAuditLogやJobへ保存しない。
- disconnect時はtokenを削除またはrevokedにし、AuditLogへsafe metadataだけを残す。
- scope追加はADRとSTRIDEレビューを必須にする。

## STRIDE

| 脅威 | リスク | 対策 |
| --- | --- | --- |
| Spoofing | Discord連携開始者やDM貼り付け者のなりすまし | 認証済みactor、project membership、OAuth state検証 |
| Tampering | 貼り付けDMやBot取得内容の改ざん | revision、review gate、AuditLog、source quote管理 |
| Repudiation | 誰が取り込み、承認し、外部送信したか追えない | actor付きAuditLog、Review history、security event |
| Information Disclosure | DM本文、token、PIIがAI/GitHub/ログへ漏れる | redaction、secret scan、暗号化、safe error、token非平文保存 |
| Denial of Service | Discord同期やAI整理の大量実行 | rate limit、job queue、対象channel/DM制限 |
| Elevation of Privilege | 広すぎるDiscord permissionやproject権限昇格 | 最小scope、scope追加ADR、project role gate |

## OWASP Top 10確認

| 観点 | 方針 |
| --- | --- |
| A01 Broken Access Control | project membershipを必須化し、非memberにはDM由来データを返さない |
| A02 Cryptographic Failures | DM本文と将来tokenは暗号化し、ログとAuditLogには本文/tokenを残さない |
| A03 Injection | DM本文をHTMLとして描画せず、AI prompt injectionをuntrusted inputとして扱う |
| A04 Insecure Design | MVPではDiscord自動取得を採用せず、手動貼り付けとreview gateで開始する |
| A05 Security Misconfiguration | Discord scope/permissionをADRで固定し、環境変数とsecret storeを分離する |
| A07 Identification and Authentication Failures | OAuth state、token失効、session revocationを必須にする |
| A09 Security Logging and Monitoring Failures | scan blocked、AI送信、承認、匿名化、disconnectを監査対象にする |
| A10 SSRF | URL preview、添付取得、外部メディア取得はMVP非スコープにする |

## 完了判定

ISSUE-006の初期設計としては、Discord連携は「MVPではDiscord側scopeなし」「将来連携はscope追加ADR必須」「self-bot禁止」「DM自動取得は非スコープ」として定義済みとする。

将来のDiscord公式連携は、別IssueでAPI利用、法務、同意、scope、token保存、rate limit、支援技術レビューを再評価する。
