# 2026-06-30 Secret scan と error masking 方針

## 目的

AI送信、GitHub publish、export、ログ保存の前に、秘密情報漏洩とエラー詳細漏洩を防ぐ。

## Secret scan対象

- Meeting raw text
- Minutes
- Requirement
- Issue Draft
- OpenAPI Draft
- AI prompt
- AI output
- Integration callback payload

## ブロック対象

- access token
- refresh token
- OAuth code
- GitHub token
- OpenAI API key
- private key
- password
- cookie
- Authorization header
- database URL
- webhook secret

## scan結果

| status | 意味 | 動作 |
| --- | --- | --- |
| clear | 検出なし | 次工程へ進める |
| warning | 低信頼または要確認 | ユーザー確認後に進める |
| blocked | 高信頼の秘密情報 | AI送信、GitHub publish、exportを停止 |

## error masking

APIやUIに返すのは `safe_error_detail` のみ。

禁止:

- stack trace全文
- token
- secret
- raw transcript
- prompt全文
- callback payload全文
- request header全文

内部調査用には `internal_error_ref` を保存し、権限のある管理者だけがサーバーログで確認する。

## Review blocker連携

secret scan statusがblockedの場合、Review blocker typeは `security_warning`、severityはP0、accepted_risk不可とする。

warningの場合はP1として、明示的な確認と監査ログを残したうえで進められる。

