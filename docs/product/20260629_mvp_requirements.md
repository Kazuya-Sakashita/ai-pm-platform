# 2026-06-29 MVP要件定義

## MVP目的

Discordまたはアップロードされた会議テキストを入力に、議事録、要件定義、GitHub Issue案、OpenAPI案、専門家レビューを生成し、改善サイクルを回せる状態にする。

## ペルソナ

### Founder/CTO

- 少人数チームでPMを兼任している。
- 会議内容をIssue化する時間がない。
- AI実装エージェントへ渡す仕様の品質を上げたい。

### Tech Lead

- 曖昧なIssueによる手戻りを減らしたい。
- API、DB、セキュリティ、テスト観点を早期にレビューしたい。

### Product Manager

- 会議、意思決定、Issue、ロードマップのつながりを追跡したい。
- 何が決まり、何が未決かを明確にしたい。

## MVPスコープ

### P0

- プロジェクト作成
- 会議テキストの登録
- Discordログの手動取り込み
- AI議事録生成
- 決定事項、未決事項、アクションアイテム抽出
- 要件定義ドラフト生成
- GitHub Issueドラフト生成
- OpenAPIドラフト生成
- 専門家ロール別レビュー生成
- レビュー結果の保存
- Issueとレビューの関連付け
- GitHub Issue作成
- ドキュメントのMarkdownエクスポート

### P1

- Discord Botによる自動取り込み
- 音声ファイルアップロードと文字起こし
- Notionエクスポート
- Google Drive保存
- GitHub Issue更新同期
- OpenAPI差分レビュー
- UI上でのレビュー承認フロー

### P2

- Slack対応
- Jira/Linear連携
- 複数AIレビュー比較
- エージェントによる実装タスク分解
- リリースノート自動生成
- DORA/SPACEメトリクス可視化

## 非スコープ

- 初期MVPでのリアルタイム音声Bot
- 完全自動実装と自動マージ
- 大企業向けSSO
- 複雑な権限階層
- 多言語UI

## 機能要件

| ID | 要件 | 優先度 | 完了条件 |
| --- | --- | --- | --- |
| FR-001 | 会議テキストを登録できる | P0 | Markdownまたはプレーンテキストを保存できる |
| FR-002 | AI議事録を生成できる | P0 | 要約、決定事項、未決事項、アクションを分離できる |
| FR-003 | 要件定義ドラフトを生成できる | P0 | 背景、目的、ユーザーストーリー、受け入れ条件が出力される |
| FR-004 | GitHub Issueドラフトを生成できる | P0 | タイトル、本文、完了条件、ラベル案が出力される |
| FR-005 | OpenAPIドラフトを生成できる | P0 | API名、path、method、request、response、errorが定義される |
| FR-006 | レビュー結果を保存できる | P0 | docs/review相当の構造で履歴が残る |
| FR-007 | GitHub Issueを作成できる | P0 | GitHub上のIssue番号とローカル台帳が紐づく |
| FR-008 | 専門家レビューを生成できる | P0 | PO、CTO、Security、QAなど複数観点の指摘が出る |

## 非機能要件

| ID | 要件 | 基準 |
| --- | --- | --- |
| NFR-001 | セキュリティ | OWASP Top 10、OAuth最小権限、監査ログ |
| NFR-002 | 可用性 | MVPは99.5%を目標、将来99.9% |
| NFR-003 | 性能 | 10,000文字の会議ログから60秒以内に初回ドラフト |
| NFR-004 | 拡張性 | Discord以外の入力ソースを追加できる |
| NFR-005 | 監査性 | 生成物、レビュー、修正履歴を追跡可能 |
| NFR-006 | UX | 非エンジニアでもIssue化まで迷わない |

## データオブジェクト

- Project
- Meeting
- Transcript
- Minutes
- Requirement
- IssueDraft
- OpenApiDraft
- Review
- Decision
- IntegrationAccount
- AuditLog

## リリース判定

MVPリリースには、P0要件の実装、レビュー保存、GitHub Issue同期、セキュリティレビュー、Playwrightまたは相当のE2Eテストが必要。

