# ADR-0009: Discord DM整理は手動インポートから始める

## Status

Accepted

## Date

2026-07-02

## Context

AI PM Platformでは、Discord DMに含まれる仕様相談、意思決定、TODOをAIで整理したい。Discord中心の開発チームでは、正式な会議よりDMで重要な合意が進むことがある。

しかし、Discord DMはプライバシーとAPI制約が強い。Discord公式ドキュメントでは、`dm_channels.read` は承認済みパートナー向けのscopeである。またBot userは通常のユーザーアカウントとは異なり、friendやGroup DM参加に制約がある。メッセージ本文取得には `MESSAGE_CONTENT` privileged intentの扱いも関わる。

参照:

- Discord OAuth2 scopes: https://docs.discord.com/developers/topics/oauth2
- Discord Gateway Message Content Intent: https://docs.discord.com/developers/events/gateway
- Discord Channel/Message API: https://docs.discord.com/developers/resources/channel

世界レベルのSaaSとしては、DMを便利に扱うだけでなく、同意、最小権限、監査、AI送信前の安全確認を必須にする必要がある。

## Decision

MVPではDiscord DMの自動取得を行わず、ユーザーが明示的に貼り付けたDMテキストだけを対象にする。

採用する:

- `discord_dm_paste` source type
- 手動貼り付け
- 保存前編集
- 同意確認
- secret/PII scan
- redaction
- AI整理ドラフト
- review gate
- AuditLog

採用しない:

- self-bot
- ユーザーアカウント自動操作
- Discord DM履歴の自動同期
- 未承認scopeを前提にした実装
- Group DMへのBot自動参加
- AI整理結果の未承認Issue化

## Consequences

### Positive

- Discord API審査や規約リスクを最小化できる。
- ユーザーが明示的に選んだ会話だけを扱える。
- DMという高センシティブデータに対して同意とredactionを挟める。
- Issue #2の会議ログ取り込みと共通基盤を再利用しやすい。
- 将来のDiscord公式連携へ段階的に進める。

### Negative

- 自動同期の便利さはMVPでは提供できない。
- ユーザーがDMをコピーする手間が残る。
- 貼り付け内容の真正性は完全には保証できない。
- 参加者同意の法的確認はプロダクト上の宣言に留まる。

## Alternatives Considered

### Discord DM自動取得から始める

不採用。

理由:

- DM関連scopeは制限が強く、初期MVPの速度と安全性に合わない。
- ユーザー同意、相手方同意、保持、削除、監査の設計が重い。
- 誤実装するとプライバシー事故の影響が大きい。

### BotとのDMだけを対象にする

将来候補。

理由:

- BotとのDMは比較的扱いやすいが、ユーザーが求めている「人同士のDM整理」とは価値が異なる。
- MVPでは手動貼り付けで価値検証を優先する。

### ブラウザ拡張でDMを取り込む

不採用。

理由:

- Discordクライアント操作やDOM scrapingに依存し、規約・保守・セキュリティリスクが高い。
- 世界レベルSaaSの信頼性に合わない。

## Implementation Follow-up

- [Todo] OpenAPIへConversation Import APIを追加する。
- [Todo] conversation_imports / conversation_summary_drafts DB設計を追加する。
- [Todo] secret/PII scanとredaction blockerを実装する。
- [Todo] AI整理prompt/schemaを `docs/ai/` に保存する。
- [Todo] DMインポートUIを設計する。
- [Todo] STRIDEレビューを実装前に再実施する。
