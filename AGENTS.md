# AGENTS.md

このプロジェクトは、AIを活用した議事録プラットフォームから AI Project Manager へ発展させるための開発ルールを定義する。

このファイルは、リポジトリ内の開発判断における最優先ルールである。ただし、システム指示、開発者指示、ユーザーからの明示指示がある場合はそれらを優先する。

## 目的

会議から、議事録、要件定義、Issue生成、API設計、実装、レビュー、テスト、リリースまでを、監査可能なAI支援ワークフローとして自動化する。

最終目標は、開発チームのPM、PdM、Tech Lead、QA、Security、Release Manager の一部機能を代替または補強する AI PM を実現することである。

## 最重要ルール

1. レビューなしで次工程へ進んではならない。
2. Issueなしで実装してはならない。
3. API駆動開発を守る。
4. 評価は世界レベルのSaaSを基準にし、必ず改善点と改善案を出す。
5. Codexは実装者だけでなく、プロジェクト全体を評価、改善、統制する役割を担う。
6. すべての重要判断は文書化する。
7. セキュリティ、品質、UX、保守性、拡張性、AI活用、ドキュメント、レビュー結果を完成条件に含める。

## 標準フェーズ

以下の各フェーズ終了時に、必ず `docs/review/` へレビューを保存する。

1. 市場調査
2. 競合分析
3. 要件定義
4. 画面設計
5. API設計
6. DB設計
7. 実装
8. レビュー
9. テスト
10. リリース

レビューがないフェーズは未完了として扱う。

## レビュー保存ルール

レビュー結果は `docs/review/YYYYMMDD_xxx_review.md` として保存する。

各レビューには必ず以下を含める。

- 評価日時
- 評価担当
- 使用フレームワーク
- 良かった点
- 改善点
- 優先順位
- 次アクション
- Issue番号

## Issue駆動開発

すべての実装、仕様変更、設計変更は Issue を起点にする。

Issueは `docs/issue/` に保存し、以下を含める。

- Issue番号
- GitHub Issue URLまたは登録待ち理由
- 背景
- 目的
- 完了条件
- スコープ
- 非スコープ
- 関連レビュー
- レビュー結果
- 次アクション

GitHub登録ができない場合は、登録できない理由をIssueファイルに明記し、登録可能になったら同じ内容でGitHub Issueへ同期する。

## API駆動開発

開発は以下の順番を守る。

1. Issue
2. 要件定義
3. OpenAPI
4. レビュー
5. 修正
6. Backend
7. Frontend
8. レビュー
9. 修正
10. テスト
11. レビュー
12. マージ

OpenAPIと実装が乖離した状態で完了扱いにしてはならない。

## ADR

技術選定、アーキテクチャ、データ保存、外部連携、AIモデル、セキュリティ方針など、後から振り返る価値がある判断は `docs/decisions/` に ADR として保存する。

## 専門家レビュー体制

Codexは、必要に応じて以下の専門家ロールの観点で評価する。

- Product Owner: 市場価値、MVP、競合、収益
- CTO: アーキテクチャ、技術負債、拡張性
- Tech Lead: 設計、API、レビュー、品質
- AI Architect: OpenAI、Codex、MCP、Agent、Prompt
- Backend Architect: Rails、Prisma、DB、OpenAPI
- Frontend Architect: Next.js、React、UX、アクセシビリティ
- DevOps: Docker、CI/CD、IaC
- Security Engineer: OAuth、認証、OWASP、監査
- QA: RSpec、Playwright、品質保証
- UI/UX Designer: デザイン、導線、Figma、ユーザビリティ
- Product Manager: ロードマップ、優先順位、リスク
- Business Consultant: 価格戦略、営業戦略、事業性
- Startup Advisor: 資金調達、IPO、組織、スケール

## 使用フレームワーク

レビュー時は課題に合わせて最適なフレームワークを選ぶ。

- G-STACK
- HEART
- RICE
- MoSCoW
- SWOT
- PEST
- Five Forces
- Lean Canvas
- Business Model Canvas
- DDD
- Event Storming
- C4 Model
- ADR
- STRIDE
- OWASP Top 10
- WCAG
- ISO25010
- DORA Metrics
- SPACE Framework

## AIレビュー方針

理想状態では Codex、Claude、ChatGPT など複数AIでレビューし、差分を比較する。

外部AIをこの環境から直接実行できない場合は、Codexレビューを一次レビューとして保存し、外部AIレビュー待ちであることを明記する。外部レビュー結果が追加された場合は、相違点、判断根拠、採用方針を追記する。

## ドキュメント配置

- `docs/architecture/`: アーキテクチャ、C4、システム構成
- `docs/api/`: OpenAPI、API設計レビュー
- `docs/issue/`: Issue台帳、GitHub Issue同期記録
- `docs/meeting/`: 会議ログ、議事録サンプル
- `docs/review/`: フェーズレビュー、AIレビュー比較
- `docs/evaluation/`: 評価基準、フレームワーク
- `docs/roadmap/`: ロードマップ、マイルストーン
- `docs/decisions/`: ADR
- `docs/security/`: セキュリティ、脅威分析、監査
- `docs/ai/`: AI設計、プロンプト、エージェント設計
- `docs/product/`: プロダクト要件、MVP、勝ち筋
- `docs/research/`: 市場調査、競合分析、ユーザー調査
- `docs/release/`: リリース計画、リリースノート

## 完成条件

動作するだけでは完成ではない。以下を満たすこと。

- 保守性がある
- 拡張性がある
- 品質が一定以上である
- 可読性がある
- テストがある
- UXが妥当である
- UIが一貫している
- セキュリティ観点の確認がある
- AI活用がプロダクト価値に直結している
- ドキュメントが更新されている
- レビュー結果と改善対応が残っている

