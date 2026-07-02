# Discord DM手動インポート セキュリティ設計

## 前提

Discord DMは、会議ログよりも個人性・機密性が高い。MVPではDiscord APIによる自動取得を行わず、ユーザーが明示的に貼り付けたテキストのみを扱う。

## P0セキュリティ要件

- DM取り込み時に同意確認を必須にする
- 取り込み前に編集・redactionできる
- AI送信前にsecret scanを実行する
- secret/PII検出時はAI送信を止める
- raw text、redacted text、AI出力、承認操作をAuditLogへ残す
- プロジェクトメンバー以外がDM由来データを閲覧できない
- DM由来データをGitHub Issueへ出す前に人間レビューを必須にする
- Discord APIからDMを自動取得しない
- self-botやユーザーアカウント自動操作を禁止する

## STRIDE

| 脅威 | リスク | 対策 |
| --- | --- | --- |
| Spoofing | 取り込み者がDM参加者でない、または同意なしに貼り付ける | consent確認、取り込み者AuditLog、将来は参加者同意ワークフロー |
| Tampering | DM内容を改ざんしてIssue化する | raw/revised revision、差分履歴、承認者記録 |
| Repudiation | 誰が取り込んだ/承認したか追えない | AuditLog、Review、consent statement version |
| Information Disclosure | 個人情報・秘密情報がAIやGitHubへ漏れる | secret scan、redaction、review gate、最小権限 |
| Denial of Service | 巨大DM貼り付けでAI cost/queueを圧迫 | 文字数上限、rate limit、job queue |
| Elevation of Privilege | 他プロジェクトのDMデータ閲覧 | project scoped authorization、テスト |

## OWASP観点

- Broken Access Control: project membership checkを全APIで必須にする
- Cryptographic Failures: tokenやsecret-like文字列を保存・表示しない
- Injection: raw textをHTMLとして描画しない
- Insecure Design: 自動DM取得をMVP非スコープにする
- Security Misconfiguration: AI provider keyとDiscord設定を環境変数管理する
- Vulnerable Components: Discord/API client導入時に依存関係監査する
- Identification and Authentication Failures: consent確認者を現在ユーザーに紐付ける
- Software and Data Integrity Failures: AI出力を未承認でIssue化しない
- Security Logging and Monitoring Failures: scan failure、blocked、overrideをAuditLogへ残す
- SSRF: URL previewや添付取得をMVPで扱わない

## データ分類

| データ | 分類 | 保存方針 |
| --- | --- | --- |
| raw DM text | Highly confidential | MVPでは保存前編集必須。暗号化/保持期間はDB設計で確定 |
| redacted text | Confidential | AI送信用の基本入力 |
| participants | Personal data | 表示名中心。Discord IDの自動取得はしない |
| AI summary | Confidential | review gate必須 |
| issue candidates | Confidential until approved | GitHub公開前に人間承認 |
| consent metadata | Audit | 削除不可期間を後続設計 |

## 禁止事項

- Discordユーザーアカウントを自動操作する
- 相手方同意のないDMを取り込む
- Discord DM履歴の全量同期を行う
- secret検出を無視してAI送信する
- AI整理結果を未承認でGitHubへ公開する
- raw DM textをdebug logへ出す

## 実装前に必要な追加設計

- raw text暗号化と保持期間
- redaction UX
- consent statementの文言とversioning
- secret/PII detectorの対象パターン
- AI prompt/schemaと引用根拠
- Review blockerの条件
- 削除/エクスポート/監査証跡の扱い
