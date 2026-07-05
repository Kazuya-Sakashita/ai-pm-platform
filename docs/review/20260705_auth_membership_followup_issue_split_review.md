# Auth / Membership follow-up Issue分割レビュー

## 評価日時

2026-07-05 16:13:52 JST

## 評価担当

Codex as Product Owner / CTO / Tech Lead / AI Architect / Backend Architect / Frontend Architect / DevOps / Security Engineer / QA / Product Manager

## 使用フレームワーク

- G-STACK
- RICE
- MoSCoW
- STRIDE
- OWASP Top 10

## Issue番号

- ISSUE-030
- ISSUE-039
- ISSUE-040
- ISSUE-038

## 評価対象

ISSUE-030完了後に残った認証/権限運用のproduction blockerを、実認証とmembership管理へ分割した。

- ISSUE-039: 実認証/JWT actor identity接続を実装する
- ISSUE-040: Project membership管理API/UIを実装する

次に実装へ進める既存Issueとして、AI送信前安全性を高める ISSUE-038 を選定した。

## 良かった点

- ISSUE-030でDM系APIのPolicy Objectを入れたため、権限境界をコードで検証できる状態になった。
- `X-Actor-Id` を暫定identityとして扱い、productionでは認証済みactorへ置換する必要を明文化できた。
- membership管理API/UIを別Issueへ切り出し、認証方式と運用導線を混ぜない粒度にした。
- ISSUE-038を先に進めることで、#35のAI provider接続前にPII/credentialの送信ブロック精度を上げられる。

## 改善点

- 実認証/JWTが未実装のため、現時点ではクライアント入力actorを完全には信頼できない。
- membershipはモデル/API guardのみで、プロダクト上の追加/変更/失効導線はまだない。
- DM以外のMeeting、Requirement、Issue Draft、GitHub連携APIにはPolicy Objectが横展開されていない。
- PII検出はsecret中心で、false positive時の確認導線もレビューされていない。

## 優先順位

| Priority | Issue | 理由 |
| --- | --- | --- |
| P0 | ISSUE-039 | actor spoofingと監査否認を解消するproduction blocker |
| P1 | ISSUE-038 | AI送信前の情報漏えいリスクを下げ、#35の前提品質になる |
| P1 | ISSUE-040 | 権限付与/剥奪の運用監査を成立させる |

## 次アクション

1. ISSUE-039とISSUE-040をGitHub Issueへ同期する。
2. ISSUE-038のSTRIDE/OWASP設計レビューを保存する。
3. SensitiveContentScannerをPII/credential/legal/financial分類へ拡張する。
4. request specとFrontend E2Eで安全なマスキング表示を検証する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM由来データの認証、権限、AI送信前安全性をproduction品質へ近づける |
| Strategy | 実認証、membership管理、PII検出を独立Issue化し、依存順に進める |
| Tactics | #39/#40を作成し、AI provider前提の#38を先に消化する |
| Assessment | 分割は妥当。ただし現時点では#39未実装のため、本番公開判定では認証がP0 blocker |
| Conclusion | 直近は#38を進め、AI送信前の漏えいリスクを下げる。その後#39へ進む |
| Knowledge | AI PM Platformでは「誰が操作したか」と「AIへ何を送るか」の両方を監査可能にする必要がある |

## STRIDE / OWASP観点

| 観点 | 残リスク | 対応Issue |
| --- | --- | --- |
| Spoofing | `X-Actor-Id` を任意指定できる | ISSUE-039 |
| Tampering | membership role変更APIがなく手作業で権限が変わる | ISSUE-040 |
| Repudiation | 認証済みuser idとAuditLogが未接続 | ISSUE-039 |
| Information Disclosure | DM内PII/credentialの検出粒度が低い | ISSUE-038 |
| Elevation of Privilege | membership運用のlast owner保護がない | ISSUE-040 |

## 判定

条件付き合格。Issue分割は適切だが、世界レベルSaaS基準では実認証/JWT未実装をP0 blockerとして扱う。次工程では#38を先に完了し、AI送信前の安全性を上げたうえで#39へ進む。

## AIレビュー比較

Codex一次レビューのみ。Claude、ChatGPTなど外部AIレビューは未実施。外部レビュー結果が追加された場合は、JWT方式、membership管理粒度、AI送信前DLP要件に差分がないか比較する。
