# 2026-06-29 市場調査

## 市場仮説

AI議事録市場はすでに混雑している。一方で、会議後の情報を実際の開発成果物へ変換し、レビュー、改善、実装、リリースまで監査可能にする領域は未成熟である。

多くのツールは「会議を忘れない」価値を提供している。本プロダクトは「会議からプロダクト開発を前に進める」価値を狙う。

## 顧客セグメント

### Primary ICP

- 5から50名規模のソフトウェア開発チーム
- DiscordやGitHubを日常的に使うチーム
- PM、Tech Lead、創業者が兼任され、要件定義やIssue化が属人化しているチーム
- AI実装エージェントを使い始めたが、入力仕様の品質に課題があるチーム

### Secondary ICP

- スタートアップのPdM、CTO、Founder
- 受託開発会社、プロダクトスタジオ
- AIエージェント導入支援会社
- オープンソースやコミュニティ主導の開発チーム

## 顧客課題

1. 会議で決まった内容がIssueや仕様に落ちない。
2. 議事録はあるが、開発者が実装できる粒度ではない。
3. AIコーディングエージェントに渡す指示が曖昧で、手戻りが発生する。
4. API設計、DB設計、セキュリティ、QAのレビューが後回しになる。
5. どの意思決定がいつ、誰の判断で決まったか追跡しにくい。
6. Slack、Discord、Notion、GitHub、Driveに情報が散らばる。

## 市場トレンド

- AI議事録ツールは会議要約から、検索、タスク化、ナレッジ化へ広がっている。
- ワークスペースAIはSlack、Notion、Atlassianなど既存SaaSに組み込まれている。
- GitHub/Codex系の開発AIは実装能力を高めているが、上流の要件品質がボトルネックになりやすい。
- AIエージェント活用が進むほど、会議、Issue、仕様、テスト、レビューの構造化が重要になる。

## 機会

本プロダクトの機会は、議事録SaaSとして真正面から戦うことではない。勝ち筋は、議事録を入口にしたエンジニアリングPM基盤になることである。

特に、以下の連鎖を標準化することに価値がある。

```text
Meeting -> Minutes -> Requirements -> Issues -> OpenAPI -> Implementation Plan -> AI Review -> Tests -> Release Notes
```

## リスク

- 議事録機能だけでは既存大手に埋もれる。
- 外部連携が多く、OAuth、権限、監査、データ保持の設計が重くなる。
- AI生成物の品質が不安定だと、PM業務の信頼を失う。
- GitHub/Notion/Discord API変更の影響を受ける。
- 音声、文字起こし、会議データはプライバシーリスクが高い。

## 市場参入方針

1. 最初は「Discord会議からGitHub Issueを作る」一点に絞る。
2. 議事録よりも「Issueと要件の品質」で差別化する。
3. レビューと改善履歴を強制保存し、AI PMとしての信頼を作る。
4. 小規模チーム向けに導入障壁を下げる。
5. 将来的にNotion、Drive、Slack、Jiraへ拡張する。

## 参考ソース

- Fireflies integrations: https://fireflies.ai/integrations
- Fathom: https://fathom.video/
- Granola: https://www.granola.ai/
- Notion AI Meeting Notes: https://www.notion.com/product/ai-meeting-notes
- Slack AI: https://slack.com/features/ai
- Atlassian Rovo: https://www.atlassian.com/software/rovo

