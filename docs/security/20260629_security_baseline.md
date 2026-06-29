# 2026-06-29 セキュリティ初期方針

## 前提

会議、議事録、Issue、要件、API設計には機密情報が含まれる。MVPでもセキュリティを後回しにしない。

## P0セキュリティ要件

- OAuthは最小権限で設計する
- 外部連携トークンは暗号化して保存する
- 生成物、プロンプト、レビュー、承認の監査ログを残す
- 会議データの保持期間を設定できる
- GitHub Issue作成前に人間承認を挟む
- AIへ送るデータ範囲を明示する
- 秘密情報検出を導入する

## 初期STRIDE

| 脅威 | リスク | 対策 |
| --- | --- | --- |
| Spoofing | Discord/GitHub連携ユーザーのなりすまし | OAuth検証、署名検証、セッション保護 |
| Tampering | AI生成IssueやOpenAPIの改ざん | 監査ログ、差分履歴、承認フロー |
| Repudiation | 誰が承認したか追えない | AuditLog、操作履歴 |
| Information Disclosure | 会議内容やトークン漏洩 | 暗号化、最小権限、秘密情報検出 |
| Denial of Service | 大量会議ログやAI呼び出しで停止 | Rate limit、Job queue、課金上限 |
| Elevation of Privilege | BotやGitHub権限の過剰付与 | Scope制限、権限レビュー |

## OWASP初期確認

- 認証と認可
- 暗号化
- 入力検証
- SSRF対策
- ログの秘匿
- 依存関係管理
- 監査証跡

