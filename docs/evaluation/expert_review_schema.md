# Expert Review Schema

## 目的

専門家サブエージェントレビューの出力を揃え、Review Orchestratorが比較、統合、衝突分析、Issue化を行えるようにする。

各Agentは自由文だけでなく、以下のschemaを満たす構造化レビューを提出する。

## 共通schema

```yaml
schema_version: "expert-review/v1"
review_id: string
review_datetime: string
reviewer:
  agent_name: string
  role: string
  mode: role_separated | codex_subagent | external_ai
  model_or_source: string
target:
  issue_number: string
  github_issue_url: string
  phase: string
  artifact: string
  artifact_type: issue | requirements | openapi | db_design | implementation | test | release | review | adr | ai_design | ui_design
  target_version_or_commit: string
  files:
    - string
  summary: string
frameworks:
  - string
verdict:
  status: pass | warning | conditional_pass | action_required | blocked | fail
  confidence: low | medium | high
  rationale: string
  blocking_status: blocking | non_blocking | needs_investigation
strengths:
  - id: string
    description: string
    evidence: string
findings:
  - id: string
    severity: P0 | P1 | P2 | P3
    category: product | architecture | api | backend | frontend | ai | security | qa | devops | ux | business | documentation
    description: string
    evidence: string
    recommendation: string
    blocking: boolean
    decision: adopt | defer | reject | investigate
    conflict_with:
      - string
    recommended_issue_action: create | update | close | none
    suggested_issue: string
risks:
  - id: string
    severity: P0 | P1 | P2 | P3
    scenario: string
    impact: string
    mitigation: string
acceptance_criteria:
  - string
reproducibility_steps:
  - string
cannot_assess:
  - reason: string
    missing_input: string
next_actions:
  - priority: P0 | P1 | P2 | P3
    action: string
    owner: string
    issue_number: string
issue_numbers:
  - string
limitations:
  - string
external_review:
  status: not_applicable | not_available | pending | completed
  notes: string
```

## 必須項目

すべてのAgentは以下を必ず出す。

- 評価日時
- Agent名
- 専門ロール
- 使用フレームワーク
- 対象Issue
- 対象ファイルまたは対象成果物
- schema version
- target artifact
- target versionまたはcommit
- 判定
- confidence
- reproducibility steps
- 良かった点
- 改善点
- 重大リスク
- 優先順位
- 次アクション
- Issue番号
- 制約または未確認事項

## 判定基準

| status | 意味 | 次工程へ進めるか |
| --- | --- | --- |
| pass | 重大な未対応リスクなし | 進める |
| warning | 軽微な注意はあるが、blockerではない | 進める |
| conditional_pass | 条件付きで進める。条件はIssueまたは同一PRで対応する | 条件付きで進める |
| action_required | 次工程前に修正が必要 | 進めない |
| blocked | 必須情報、必須Agent、P0判断が不足している | 進めない |
| fail | 目的や完成条件を満たしていない | 進めない |

## Severity

| Severity | 意味 | 扱い |
| --- | --- | --- |
| P0 | セキュリティ、データ保護、認証、監査、破壊的障害、重大な顧客価値毀損 | 次工程ブロック |
| P1 | 主要UX、API契約、回帰、運用、品質に大きな影響 | 原則として同一Issueで対応 |
| P2 | 保守性、拡張性、観測性、改善余地 | 後続Issue化可能 |
| P3 | 文言、軽微な整合性、将来改善 | backlogへ送る |

## Category

| Category | 対象 |
| --- | --- |
| product | 顧客価値、MVP、優先順位 |
| architecture | システム構成、責務分離、拡張性 |
| api | OpenAPI、contract、互換性 |
| backend | Rails、DB、job、service、policy |
| frontend | Next.js、React、state、client |
| ai | OpenAI、Codex、prompt、Agent、Structured Outputs |
| security | 認証、認可、OWASP、STRIDE、監査 |
| qa | RSpec、Playwright、回帰、品質保証 |
| devops | CI/CD、Docker、環境差分、運用 |
| ux | 導線、アクセシビリティ、情報設計 |
| business | 収益、販売、競合、資金調達 |
| documentation | docs、ADR、review、Issue台帳 |

## Agent別必須チェック

### Product Owner Agent

- 顧客価値が明確か
- MVPとして過不足がないか
- 競合との差別化につながるか
- 収益、継続利用、導入障壁への影響があるか

### CTO Agent

- 将来の拡張を妨げないか
- 技術負債を増やしすぎていないか
- ADRが必要な判断が文書化されているか
- 運用、障害対応、監査に耐えるか

### Tech Lead Agent

- API contractと実装方針が一致しているか
- 責務分離が妥当か
- 過剰設計または密結合がないか
- レビュー可能な粒度か

### AI Architect Agent

- AI出力schemaが明確か
- prompt injection、hallucination、unsafe outputへの対策があるか
- AI判断と人間承認の境界が明確か
- 評価方法とmanual smokeが定義されているか

### Backend Architect Agent

- Rails Controller/Modelへ処理を詰め込みすぎていないか
- Service/Policy/Validator/Adapter分離が妥当か
- DB migration、index、rollback、seed影響が明確か
- request specで失敗系を固定しているか

### Frontend Architect Agent

- API clientとOpenAPI contractが一致しているか
- エラー状態、loading、empty、permission deniedがあるか
- 日本語表示と再ログイン導線が妥当か
- WCAG観点で操作できるか

### Security Engineer Agent

- 認証済みidentityを信頼境界にしているか
- 任意ヘッダーやclient入力を信頼していないか
- STRIDE/OWASP Top 10の主要リスクを検討しているか
- AuditLogにsafe metadataだけを残しているか
- secret、PII、raw provider responseを保存していないか

### QA Agent

- request spec、service spec、E2Eの責務分担が明確か
- happy pathだけでなくfailure pathがあるか
- 回帰しやすい契約をテストしているか
- CIで再現できるか

### DevOps Agent

- CI/CDで検証できるか
- local/staging/production差分が文書化されているか
- secret/env/worker/queueの運用が明確か
- smoke testとrollback方針があるか

### UI/UX Designer Agent

- ユーザーの次アクションが明確か
- 重要な警告と通常情報の視覚優先度が妥当か
- 文言がプロダクトの日本語方針に合うか
- 操作ミスを防げるか

### Business Consultant Agent

- 収益化や導入価値につながるか
- 競合優位性が説明できるか
- enterprise buyerに説明できる監査性があるか
- MVP後の販売/価格仮説に接続できるか

## Orchestrator統合schema

```yaml
integrated_review_id: string
review_datetime: string
orchestrator: string
target_issue: string
participating_agents:
  - string
overall_verdict:
  status: pass | conditional_pass | action_required | fail
  rationale: string
agent_summaries:
  - agent_name: string
    verdict: string
    top_findings:
      - string
merged_findings:
  - id: string
    severity: P0 | P1 | P2 | P3
    source_agents:
      - string
    description: string
    decision: adopt | defer | reject | investigate
    decision_reason: string
conflicts:
  - id: string
    agents:
      - string
    conflict: string
    resolution: string
    rationale: string
priority_plan:
  - priority: P0 | P1 | P2 | P3
    action: string
    issue_number: string
documentation_updates:
  - string
external_ai_comparison:
  status: not_available | pending | completed
  notes: string
```

## Red flags

以下がある場合は `action_required` 以上にする。

- P0指摘があるのにIssue化されていない
- 改善点がないレビュー
- 使用フレームワークが対象に合っていない
- 根拠のない「問題なし」
- 外部AI未実施なのに完了扱いしている
- Security/QAが必要な対象で、そのAgentレビューがない
- OpenAPIやADRが必要な変更で文書がない
- レビュー結果がGitHub Issueまたはdocs/issueに同期されていない

## Invalid review conditions

以下のレビューはschema-invalidとして扱い、AGENTS.md上のレビュー完了条件を満たさない。

- `schema_version` がない。
- 対象Issue番号がない。
- 対象artifactまたは対象ファイルがない。
- 対象version/commitまたは変更範囲が不明である。
- 使用フレームワークがない。
- verdictがない。
- confidenceがない。
- evidenceがない。
- severityがない改善点だけが並んでいる。
- next_actionsがない。
- Security/QAが必須の対象で、独立したSecurity/QA判定がない。
- P0 blockerの採用、保留、却下、追加調査の判断がない。
- cannot_assessを出しているのに、追加調査またはblock判断がない。
- 外部AIレビュー未実施なのに、未実施理由やfallbackがない。

schema-invalidなレビューは、`docs/review/` に保存されていても次工程のゲート通過には使えない。

## 保存例

レビュー文書では、全文schemaをYAMLで保存してもよいが、通常は読みやすいMarkdownに展開する。

必須セクション:

- 評価日時
- 評価担当
- 使用フレームワーク
- Issue番号
- 参加Agent
- Agent別サマリー
- 統合判定
- 良かった点
- 改善点
- 優先順位
- 次アクション
- 衝突分析
- AIレビュー比較
