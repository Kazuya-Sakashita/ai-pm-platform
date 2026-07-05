# ISSUE-041: 専門家サブエージェントレビュー運用基盤を設計・導入する

## Issue番号

ISSUE-041

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/41

登録日: 2026-07-05
クローズ日: 2026-07-05
クローズ同期コメント: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/41#issuecomment-4885414580

## 背景

AGENTS.mdでは、CodexがProduct Owner、CTO、Tech Lead、AI Architect、Backend Architect、Frontend Architect、Security Engineer、QA、DevOps、UI/UX Designer、Product Manager、Business Consultant、Startup Advisorなどの専門家視点でレビューすることを定めている。

現状はCodex単体が複数観点をまとめて評価しているため、レビュー観点の網羅性はある一方で、各専門家の責務、評価フレームワーク、合否基準、改善提案の責任範囲が十分に分離されていない。

AI PM Platformを世界レベルのSaaS品質へ引き上げるには、専門家レビューをサブエージェント化し、各Agentが独立した観点で厳しく評価し、Orchestratorが差分、衝突、優先順位、Issue化を統合する運用が必要である。

## 目的

専門家サブエージェントレビューの運用基盤を設計・導入し、プロダクト、技術、AI、セキュリティ、QA、UX、事業性の評価品質を引き上げる。

単なるレビュー文書の分担ではなく、AI PMの中核機能として、以下を実現する。

- 専門家ごとの責務分離
- 専門家ごとの評価フレームワーク固定
- 専門家レビューの出力schema標準化
- Orchestratorによる統合評価
- 意見衝突の検出と判断根拠の記録
- 改善Issue、ADR、Roadmapへの接続
- 外部AIレビューを追加できる拡張性

## 完了条件

- `docs/ai/expert_subagents.md` に専門家サブエージェント構成、責務、起動条件、Orchestratorの統合手順が定義されている
- `docs/evaluation/expert_review_schema.md` に各Agent共通のレビュー出力schemaが定義されている
- `docs/decisions/` に専門家サブエージェントレビュー運用のADRが保存されている
- `AGENTS.md` に専門家サブエージェント運用ルールが追記されている
- Product Owner、CTO、Tech Lead、AI Architect、Security Engineer、QA、Frontend Architect、Backend Architect、DevOps、UI/UX Designer、Business Consultantの初期Agent定義がある
- 各Agentの評価フレームワーク、必須チェック項目、合否基準、改善提案フォーマットが定義されている
- Orchestratorが専門家レビューを統合し、採用、保留、却下、追加調査を判断するルールがある
- レビュー結果を `docs/review/` へ保存する命名規則とテンプレートがある
- 最低1つの既存Issueまたは次の実装Issueで、専門家サブエージェントレビューのパイロットが実施されている
- パイロット結果のレビューが `docs/review/` に保存されている
- GitHub Issueへ実装結果とレビュー結果が同期されている

## スコープ

- 専門家サブエージェント運用設計
- Agent責務定義
- Agent別レビューschema
- Orchestrator統合ルール
- 衝突分析ルール
- レビュー保存テンプレート
- AGENTS.md運用ルール追記
- ADR作成
- パイロットレビュー実施
- GitHub Issue同期

## 非スコープ

- 外部AIサービスとの自動連携実装
- Claude、ChatGPTなど外部AIレビューの実API接続
- Review Center UIへのサブエージェント結果表示
- DB永続化されたAgent実行履歴
- 自動スケジューリング
- 課金、組織、権限モデルの変更

## 推奨手順

1. Governance設計
   - 専門家Agent一覧、責務、起動条件、レビュー対象、非責務を定義する。
   - Orchestratorが最終判断者であることを明確にする。

2. Review Schema設計
   - 各Agent共通の出力項目を定義する。
   - 必須項目は、評価日時、Agent名、使用フレームワーク、評価対象、良かった点、改善点、重大リスク、優先順位、次アクション、Issue番号、信頼度、根拠にする。

3. Agent別プロファイル定義
   - Product Owner Agentは市場価値、MVP、収益性を見る。
   - CTO Agentは拡張性、技術負債、アーキテクチャを見る。
   - Tech Lead Agentは設計品質、API契約、保守性を見る。
   - AI Architect AgentはOpenAI、Codex、MCP、Agent設計、Prompt、Structured Outputsを見る。
   - Security Engineer AgentはOAuth、認証、OWASP、STRIDE、監査を見る。
   - QA AgentはRSpec、Playwright、回帰、テスト戦略を見る。
   - Frontend Architect AgentはNext.js、React、UX、WCAGを見る。
   - Backend Architect AgentはRails、DB、OpenAPI、ジョブ基盤を見る。
   - DevOps AgentはCI/CD、Docker、環境差分、運用性を見る。
   - UI/UX Designer Agentは導線、情報設計、視覚一貫性を見る。
   - Business Consultant Agentは価格、販売戦略、事業性を見る。

4. Orchestrator統合設計
   - 各Agentの指摘を重要度、緊急度、根拠、影響範囲で統合する。
   - 指摘の衝突を記録し、採用、保留、却下、追加調査を決める。
   - RICE、MoSCoW、G-STACKを使って優先順位を確定する。

5. ADR作成
   - なぜ専門家サブエージェント方式を採用するのかを記録する。
   - 単一Codexレビュー、外部AIレビュー、将来の実Agent実装との比較も残す。

6. AGENTS.md追記
   - 今後の重要レビューでは、必要に応じて専門家サブエージェントレビューを実施することを明記する。
   - 外部AIが使えない場合はCodex内サブエージェントまたはロール分離レビューを一次レビューとして扱う。

7. パイロット実施
   - 次の候補はISSUE-039またはISSUE-040。
   - 認証、権限、監査に関わるため、初回パイロットはISSUE-039が望ましい。

8. レビューと改善
   - パイロット結果を `docs/review/` に保存する。
   - Agent数が多すぎる場合は、必須Agentと任意Agentを分ける。
   - 手戻り、重複、レビュー品質、Issue化精度を評価する。

## 推奨Agent構成

| Agent | 主責務 | 推奨フレームワーク |
| --- | --- | --- |
| Review Orchestrator | 統合、衝突分析、優先順位、Issue化 | G-STACK, RICE, MoSCoW |
| Product Owner Agent | 市場価値、MVP、顧客価値 | Lean Canvas, RICE, MoSCoW |
| CTO Agent | アーキテクチャ、拡張性、技術負債 | C4 Model, ISO25010, ADR |
| Tech Lead Agent | 設計品質、API契約、保守性 | DDD, OpenAPI, ISO25010 |
| AI Architect Agent | AI品質、Prompt、Agent設計 | G-STACK, Structured Outputs, evaluation rubric |
| Backend Architect Agent | Rails、DB、ジョブ、API | DDD, Event Storming, OpenAPI |
| Frontend Architect Agent | Next.js、UX、アクセシビリティ | WCAG, HEART, ISO25010 |
| Security Engineer Agent | 認証、認可、監査、脅威分析 | STRIDE, OWASP Top 10 |
| QA Agent | テスト戦略、E2E、品質保証 | ISO25010, DORA Metrics |
| DevOps Agent | CI/CD、Docker、運用、可観測性 | DORA Metrics, SPACE Framework |
| UI/UX Designer Agent | 情報設計、導線、視覚品質 | HEART, WCAG |
| Business Consultant Agent | 価格、営業、収益性 | Business Model Canvas, Five Forces |
| Startup Advisor Agent | 資金調達、組織、スケール | Lean Canvas, PEST |

## 関連レビュー

- `AGENTS.md`
- `docs/review/` 配下の既存フェーズレビュー
- `docs/review/20260705_expert_subagent_governance_review.md`
- `docs/review/20260705_expert_subagent_pilot_issue_039_review.md`

## 関連ドキュメント

- `docs/ai/expert_subagents.md`
- `docs/evaluation/expert_review_schema.md`
- `docs/decisions/ADR-0015_expert_subagent_review_operations.md`

## レビュー結果

Codex一次レビューでは、専門家視点を一つのレビュー内にまとめる現行方式は初期運用として妥当。ただし、世界レベルSaaS基準では、専門家ごとの独立した評価基準、出力schema、合否判定、衝突分析、改善Issue化の仕組みがないと、レビュー品質が属人的になりやすい。

まずは外部AI実行やDB永続化に進まず、ドキュメント、テンプレート、ADR、AGENTS.md追記、ISSUE-039でのパイロットから始めるのが安全である。

2026-07-05に専門家サブエージェントレビュー運用基盤を実装した。`docs/ai/expert_subagents.md` でL1/L2/L3、Agent責務、必須Agent、Orchestrator統合、衝突分析、フェーズゲート、外部AI fallback、ISSUE-039パイロット方針を定義した。`docs/evaluation/expert_review_schema.md` でschema version、target artifact、target version/commit、evidence、confidence、reproducibility、blocking status、invalid review conditionsを定義した。

ADR-0015では、単一Codexレビュー、外部AI必須化、全Issue全Agent必須化、DB永続化先行を比較し、段階的な専門家サブエージェントレビュー運用を採用した。

実際にCodex subagentとしてSecurity Engineer + QA Agent、Product Owner + CTO + AI Architect Agentを並行実行し、指摘を反映した。主な反映点は、Security/QA blocker、Agent独立判定、schema-invalidレビュー無効化、ISSUE-005との接続、外部AI Adapter方針である。

ISSUE-039を対象に初回パイロットレビューを保存し、認証/JWT actor identity実装前にP0条件、OpenAPI security scheme、`X-Actor-Id` 廃止境界、AuditLog actor mapping、Frontend再ログイン導線を確認した。

検証結果:

- `git diff --check`: success
- GitHub Actions CI `28734974002`: success（commit `4736277`）

## 優先度

P1

理由:

- AI PM Platformの差別化要素であるレビュー品質に直結する
- ISSUE-039以降の認証、権限、監査、AI生成、Review Centerの品質を底上げできる
- 実装より先に運用ルールとschemaを固めることで、後戻りを減らせる
- 将来の外部AIレビューやReview Center表示へ拡張しやすい

## 次アクション

1. GitHub Issue #41はクローズ済み。
2. 次はISSUE-039を、専門家サブエージェントレビュー前提で進める。
