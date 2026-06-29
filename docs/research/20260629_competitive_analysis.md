# 2026-06-29 競合分析

## 対象市場

AI議事録、AI会議アシスタント、AIプロジェクト管理、エンジニアリング自動化、ナレッジ管理の交差領域。

本プロダクトは単なる議事録ではなく、会議内容を開発成果物へ変換する AI PM プラットフォームを目指す。

## 競合マップ

| 領域 | 代表例 | 強み | 弱み | 本プロダクトの差別化余地 |
| --- | --- | --- | --- | --- |
| AI議事録 | Otter, Fireflies, Fathom, Granola | 文字起こし、要約、アクションアイテム抽出、会議検索 | 要件定義、API設計、実装レビューまでは弱い | 会議からGitHub Issue、OpenAPI、実装レビューまで接続する |
| ワークスペースAI | Notion AI Meeting Notes, Slack AI | 既存ワークスペース内で導入しやすい | エンジニアリング成果物への厳密変換が弱い | GitHub、OpenAPI、ADR、レビューを第一級オブジェクトにする |
| プロジェクト管理AI | Atlassian Rovo, ClickUp Brain | チケット、Wiki、検索、業務AI | エコシステムロックインが強い | Discord/GitHub/OpenAI/Codex/Notion/Driveを横断する |
| 開発AI | GitHub Copilot, Codex, Devin系 | 実装、PR、レビュー補助 | 会議、意思決定、要件、優先順位との接続が弱い | 開発前工程を構造化して実装AIへ渡す |

## 主要競合

### Otter

強み:

- 会議録、要約、AIチャット、会議検索の認知度が高い。
- 複数会議のナレッジを横断して質問できる方向に進化している。

弱み:

- プロダクト開発工程のIssue、OpenAPI、ADR、レビュー、テストまでを標準ワークフロー化しているわけではない。
- エンジニアリング組織の品質ゲートとしては不足。

### Fireflies

強み:

- 多数の会議ツール、CRM、タスク管理、ストレージと連携する広い統合面。
- AI要約、検索、トピック抽出、会議後ワークフローに強い。

弱み:

- 汎用会議分析が中心で、ソフトウェア開発の成果物生成は主戦場ではない。
- ReviewOps、API駆動、Issue駆動を強制するガバナンスは弱い。

### Fathom

強み:

- AIノートテイカーとして導入障壁が低い。
- CRMやSlackなど営業、CS寄りの会議ワークフローと相性がよい。
- APIやMCP方向の拡張が見える。

弱み:

- ソフトウェア開発プロセスを統制するPMプラットフォームではない。
- 議事録後の要件、仕様、実装、テストまでの監査線が不足。

### Granola

強み:

- ボット参加型ではなく、個人の会議メモをAIで補完する体験が軽い。
- 会議中の人間の集中を邪魔しない。

弱み:

- チーム横断の開発プロセス、Issue駆動、API駆動の統制には向かない。
- 企業統制、権限、監査、CI連携では追加設計が必要。

### Notion AI Meeting Notes

強み:

- 会議メモ、プロジェクト、Wiki、タスクが同じワークスペースに存在する。
- 非エンジニアにも使いやすい。

弱み:

- Notion中心の情報管理で、GitHub/OpenAPI/Codexを中心にした開発実行までは弱い。
- リリース品質、セキュリティレビュー、テストゲートを強制しにくい。

### Atlassian Rovo

強み:

- Jira、Confluence、Loomなど開発組織の既存資産と密接に結合している。
- ナレッジ検索、エージェント、チケット更新に強い。

弱み:

- Atlassianエコシステム依存が強い。
- Discord中心のチーム、GitHub中心の軽量チーム、AI実装エージェント活用チームには重い場合がある。

## 勝てる領域

1. Discord-first の開発チーム向けAI PM
2. GitHub Issue、OpenAPI、ADR、レビューを会議から自動生成するプロダクト開発特化
3. レビュー結果を永続化し、改善サイクルを強制する ReviewOps
4. Codexなど実装AIへ渡せる、曖昧さの少ない仕様生成
5. 小規模からスタートし、Notion/Drive/Slackへ拡張できる軽量統合

## 参考ソース

- Fireflies integrations: https://fireflies.ai/integrations
- Fathom: https://fathom.video/
- Granola: https://www.granola.ai/
- Notion AI Meeting Notes: https://www.notion.com/product/ai-meeting-notes
- Slack AI: https://slack.com/features/ai
- Atlassian Rovo: https://www.atlassian.com/software/rovo

