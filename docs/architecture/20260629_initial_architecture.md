# 2026-06-29 初期アーキテクチャ構想

## 方針

MVPは複雑なマイクロサービス化を避け、拡張可能なモジュラーモノリスから始める。

推奨初期構成:

- Frontend: Next.js, React, TypeScript
- Backend: Rails API, PostgreSQL, ActiveRecord
- API contract: OpenAPI
- Jobs: SidekiqまたはSolid Queue
- AI orchestration: OpenAI APIを抽象化したAgent service
- Storage: S3互換ストレージまたはGoogle Drive連携を将来追加
- Integrations: GitHub App/OAuth、Discord Bot、Notion、Google Drive、Slack

Prismaは、将来TypeScriptバックエンドまたは独立Nodeサービスを採用する場合に再評価する。Rails APIを採用する間はActiveRecordを標準とする。

## C4 Context

```text
User
  -> AI PM Platform
    -> Discord
    -> GitHub
    -> OpenAI
    -> Codex
    -> Notion
    -> Google Drive
    -> Slack future
```

## 主要コンポーネント

- Meeting Ingestion: Discordログ、手動テキスト、将来音声
- Transcript/Minutes Pipeline: 文字起こし、要約、決定事項抽出
- Requirement Generator: 要件定義、受け入れ条件、非機能要件
- Issue Generator: GitHub Issue案と同期
- OpenAPI Generator: APIドラフトとレビュー
- Review Engine: 専門家ロール別レビュー、フレームワーク選択
- Artifact Store: 議事録、要件、Issue、ADR、レビューを保存
- Integration Layer: OAuth、Webhook、API client
- Audit Log: 誰が、いつ、何を生成、修正、承認したか記録

## 境界づけられたコンテキスト

- Project Management
- Meeting Intelligence
- Requirement Engineering
- Issue Automation
- API Design
- AI Review
- Integration
- Security and Audit

## 初期リスク

- AI生成物の一貫性
- 外部APIの権限管理
- 会議データの機密性
- 生成Issueの品質保証
- 複数ツール連携の状態管理

## 初期対策

- OpenAPIとレビューを実装前ゲートにする
- 生成物は必ず人間承認可能にする
- 外部連携は最小権限で開始する
- AuditLogをP0に含める
- AIプロンプト、モデル、入力、出力、レビューを保存する

