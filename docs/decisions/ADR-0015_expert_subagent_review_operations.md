# ADR-0015: 専門家サブエージェントレビュー運用を採用する

## Status

Accepted

## Date

2026-07-05

## Context

AGENTS.mdでは、CodexがProduct Owner、CTO、Tech Lead、AI Architect、Backend Architect、Frontend Architect、Security Engineer、QA、DevOps、UI/UX Designer、Product Manager、Business Consultant、Startup Advisorの観点でレビューすることを求めている。

これまではCodex単体が複数観点をまとめて評価していた。この方式は速いが、専門家ごとの責務、出力schema、合否基準、衝突分析が弱くなりやすい。特に認証、AI provider、OpenAPI、DB、リリース判定のような高リスク領域では、単一レビューでは見落としや甘い評価が残る。

AI PM Platformの中核価値は、会議からIssue、API、実装、レビュー、リリースまでを監査可能に進めることである。そのため、レビュー自体も監査可能で、専門性の分離と統合判断を持つ必要がある。

## Decision

専門家サブエージェントレビュー運用を採用する。

初期段階では以下の3段階で運用する。

1. L1: Codex内のrole-separated review
2. L2: Codex subagent review
3. L3: Codex、Claude、ChatGPTなどのexternal AI comparison

通常はL1を使う。認証、認可、監査、AI provider、OpenAPI、DB、リリース判定などの重要領域ではL2を推奨する。外部AIを利用できる場合はL3で差分比較する。

Review Orchestratorを最終統合役とし、各専門家Agentの指摘を採用、保留、却下、追加調査へ分類する。単純な多数決ではなく、P0セキュリティ、データ保護、監査、API/DBの後戻りコストを優先して判断する。

## Rationale

- 専門家ごとの責務を分けることで、レビュー観点の抜けを減らせる。
- SecurityやQAのP0指摘をProduct都合で見落としにくくなる。
- Orchestratorが衝突分析を残すことで、後から判断理由を監査できる。
- レビュー出力schemaを揃えることで、将来のReview Center UIやDB保存に接続しやすい。
- 外部AIレビューが使えない場合でも、Codex内サブエージェントやロール分離レビューで一次レビューを継続できる。

## Alternatives Considered

### 単一Codexレビューを継続する

不採用。

理由:

- 速いが、専門家ごとの合否基準が曖昧になりやすい。
- 複雑なIssueで指摘の重み付けが属人的になる。
- AI PM Platformの差別化要素であるレビュー品質を説明しにくい。

### 外部AIレビューだけを必須にする

現時点では不採用。

理由:

- この環境から常にClaude、ChatGPTなどを実行できるとは限らない。
- 外部AI実行待ちを全工程のblockerにすると開発速度が落ちる。
- まずはCodex内の運用schemaと統合判断を固めた方が安全である。

### 全Issueで全専門家Agentを必須にする

不採用。

理由:

- 軽微な変更でもレビュー負荷が高くなる。
- 重複指摘が増え、重要Issueへの集中力が下がる。
- 対象ごとに必須Agentと任意Agentを分ける方が実用的である。

### すぐにDB永続化されたAgent実行履歴を実装する

現時点では不採用。

理由:

- 運用schemaが固まる前にDB設計すると手戻りが大きい。
- まずはMarkdown docsで監査可能性とレビュー品質を検証する。
- Review Center連動は後続Issueで扱う方がよい。

## Consequences

良い影響:

- レビュー品質と説明責任が上がる。
- 重要IssueでSecurity/QA/AI/Architectureの見落としを減らせる。
- 改善Issue、ADR、Roadmapへの接続が明確になる。
- 将来の外部AIレビュー比較やReview Center表示へ拡張しやすい。

トレードオフ:

- 重要Issueではレビュー時間が増える。
- Orchestratorが重複指摘を統合する手間が増える。
- サブエージェント出力の品質が低い場合、採用/保留/却下の判断が必要になる。

## Follow-up

- `docs/ai/expert_subagents.md` で運用手順を定義する。
- `docs/evaluation/expert_review_schema.md` で出力schemaを定義する。
- AGENTS.mdに専門家サブエージェントレビュー運用ルールを追加する。
- ISSUE-039で初回パイロットレビューを実施する。
- 将来、Review CenterへAgent別レビュー結果を表示するIssueを作成する。
