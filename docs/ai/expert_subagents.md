# Expert Subagent Review Operations

## 目的

専門家サブエージェントレビューは、AI PM Platformの成果物を単一視点で評価せず、Product、Architecture、AI、Security、QA、UX、DevOps、Businessの専門観点へ分解して、世界レベルSaaS基準で改善するための運用である。

この運用は「専門家名を付けた感想」ではない。各Agentに責務、対象外、使用フレームワーク、合否基準、出力schemaを持たせ、Review Orchestratorが差分、衝突、優先順位、Issue化を統合する。

## 全Agent共通の6価値軸

すべての専門家サブエージェントは、自身の専門領域だけでなく、以下6項目への影響を評価する。これは既存の専門責務を置き換えるものではなく、レビューの最低共通軸である。

| 価値軸 | 確認観点 | 代表Agent |
| --- | --- | --- |
| 強固なセキュリティ | Security by Design、OWASP Top 10、STRIDE、最小権限、認証、認可、入力値検証、監査ログ、秘密情報管理 | Security, Backend, DevOps, QA |
| 高い技術品質 | 保守性、拡張性、可読性、テスト容易性、パフォーマンス、責務分離 | CTO, Tech Lead, Backend, Frontend, QA |
| 優れたユーザー体験 | 直感的な操作、ストレスの少ないUI/UX、アクセシビリティ、日本語表示品質 | UI/UX, Frontend, Product Owner, QA |
| 継続して利用したくなる体験 | 習慣化、再訪価値、エンゲージメント、通知やレビュー導線の妥当性 | Product Owner, Product Manager, UI/UX |
| 事業としての価値 | ユーザー課題、差別化、導入価値、収益性、成長可能性 | Product Owner, Business, Startup Advisor |
| 長期運用できる設計 | 将来拡張、技術的負債、安定運用、監査性、障害対応、運用コスト | CTO, DevOps, Security, QA |

技術的に実装可能であることだけを合格条件にしてはならない。Review Orchestratorは、ユーザー、開発者、運営者の三者にとって長期的に価値があるかを統合判定に含める。

セキュリティは共通軸の中でも最優先事項の一つとして扱う。Security Engineer AgentまたはQA AgentがP0 blockerを出した場合、明示的なリスク受容または修正なしに次工程へ進めない。

## 運用レベル

| Level | 名称 | 内容 | 利用条件 |
| --- | --- | --- | --- |
| L1 | Role-separated review | Codexが専門家ロールを分離してレビューする | 軽量なdocs更新、初期設計 |
| L2 | Codex subagent review | Codex内のサブエージェントを使い、独立した観点で並行レビューする | セキュリティ、認証、AI送信、API/DB設計、リリース判定 |
| L3 | External AI comparison | Codex、Claude、ChatGPTなど複数AIレビューを比較する | 重要なリリース、AI品質、セキュリティ、事業戦略 |

外部AIを実行できない場合は、L1またはL2を一次レビューとして保存し、外部AIレビュー待ちであることを明記する。

## 起動条件

以下のいずれかに当てはまる場合、L2以上の専門家サブエージェントレビューを推奨する。

- 認証、認可、監査、秘密情報、個人情報を扱う
- AI provider、prompt、Structured Outputs、Agent設計を変更する
- OpenAPI、DB schema、API contract、ジョブ基盤を変更する
- リリース、production smoke、運用手順に関わる
- Review Center、Issue生成、要件化などAI PM中核workflowに関わる
- ユーザー導線、継続利用、主要業務フロー、導入価値に強く影響する
- 仕様が曖昧で、プロダクト価値と技術実現性の両方を判断する必要がある

軽微な文言修正、誤字修正、すでにレビュー済みの台帳同期だけの場合は、L1または通常レビューでよい。

## AI PMとしての差別化価値

専門家サブエージェントレビューは、AI PM Platformを「AIが成果物を作るツール」から「AIが成果物を評価し、次工程を統制するプラットフォーム」へ引き上げる。

解決するユーザー課題:

- PMやTech Leadが見落としがちなセキュリティ、QA、運用リスクを早期に出す。
- 会議、要件、Issue、API、実装、レビューのつながりを監査可能にする。
- 複数専門家の指摘をIssue、ADR、Roadmapへ接続し、手戻りを減らす。
- 重大リスクが残るまま「レビュー済み」と扱われる状態を防ぐ。

## Agent独立性ルール

- 各AgentはOrchestratorの要約材料ではなく、独立した合否、重大リスク、改善案を提出する。
- Security Engineer AgentとQA Agentは、対象が認証、認可、個人情報、AI送信、releaseに関わる場合、独立したblocking判定を持つ。
- OrchestratorはSecurity/QAのP0 blockerを勝手に却下してはならない。却下する場合は、リスク受容者、理由、代替策、後続Issueを記録する。
- Agentが判断不能な場合は `cannot_assess` として扱い、推測でpassにしない。
- Agent間の重複指摘はOrchestratorが統合するが、元のsource agentは残す。

## フェーズゲート

以下の状態では、次工程へ進めない。

- 必須Agentレビューが欠けている。
- レビューがschema-invalidである。
- P0 blockerが未解決またはリスク受容されていない。
- 対象Issue、artifact、commit、レビュー日時が不明である。
- Security/QAが必要な対象なのに、Security/QAの独立判定がない。
- 外部AIレビュー必須と定義したのに、未実施理由やfallbackが記録されていない。
- Agent間の重大衝突が未解決である。

stale reviewの目安:

- 対象artifactが変更された後のレビューでない。
- 対象Issueの完了条件が更新された後、再レビューされていない。
- API/DB/security boundaryが変わったのに、古いレビューだけで進めようとしている。

## Agent構成

| Agent | 主責務 | 対象外 | 推奨フレームワーク |
| --- | --- | --- | --- |
| Review Orchestrator | 統合、衝突分析、優先順位、Issue化、最終判定 | 個別領域の詳細実装を単独で決めること | G-STACK, RICE, MoSCoW |
| Product Owner Agent | 顧客価値、MVP、差別化、収益仮説 | 実装方式の細部 | Lean Canvas, RICE, MoSCoW |
| Product Manager Agent | ロードマップ、スコープ、リスク、依存関係 | コード品質の詳細 | G-STACK, RICE |
| CTO Agent | アーキテクチャ、拡張性、技術負債、運用コスト | UI文言の細部 | C4 Model, ISO25010, ADR |
| Tech Lead Agent | 設計品質、API契約、保守性、責務分離 | 市場調査の詳細 | DDD, OpenAPI, ISO25010 |
| AI Architect Agent | OpenAI、Codex、MCP、Agent、Prompt、Structured Outputs、評価設計 | 価格戦略の最終判断 | G-STACK, evaluation rubric |
| Backend Architect Agent | Rails、DB、OpenAPI、ジョブ、Service/Policy分離 | Visual design | DDD, Event Storming, OpenAPI |
| Frontend Architect Agent | Next.js、React、状態管理、UX、アクセシビリティ | DB物理設計 | WCAG, HEART, ISO25010 |
| Security Engineer Agent | OAuth、認証、認可、監査、STRIDE、OWASP、データ保護 | 事業KPIの最終判断 | STRIDE, OWASP Top 10 |
| QA Agent | RSpec、Playwright、回帰リスク、テスト戦略、再現性 | 価格戦略 | ISO25010, DORA Metrics |
| DevOps Agent | Docker、CI/CD、IaC、環境差分、可観測性、release smoke | Product copyの細部 | DORA Metrics, SPACE Framework |
| UI/UX Designer Agent | 情報設計、導線、一貫性、WCAG、認知負荷 | Backend実装方式 | HEART, WCAG |
| Business Consultant Agent | 価格、販売、競合、事業性 | セキュリティ実装詳細 | Business Model Canvas, Five Forces |
| Startup Advisor Agent | 資金調達、組織、スケール、IPO耐性 | API contract詳細 | Lean Canvas, PEST |

## 必須Agentと任意Agent

すべてのレビューで全Agentを呼ぶと、重複と遅延が増える。対象に応じて必須Agentを絞る。

| 対象 | 必須Agent | 任意Agent |
| --- | --- | --- |
| 認証/認可/監査 | Security, Backend, QA, CTO, Orchestrator | Frontend, DevOps |
| AI provider/prompt | AI Architect, Security, QA, Product Owner, Orchestrator | Backend, CTO |
| OpenAPI/API設計 | Tech Lead, Backend, Frontend, QA, Orchestrator | Security, DevOps |
| DB/データ保護 | Backend, Security, CTO, QA, Orchestrator | DevOps |
| Frontend UX | Frontend, UI/UX, QA, Product Owner, Orchestrator | Security |
| リリース判定 | DevOps, QA, Security, Product Manager, Orchestrator | CTO, Business |
| 事業/ロードマップ | Product Owner, Product Manager, Business, Startup Advisor, Orchestrator | CTO |

## 実行手順

1. Review OrchestratorがIssue、対象ファイル、前提、レビュー観点、必須Agentを決める。
2. 各Agentへ、対象、責務、非責務、出力schema、参照すべきIssue/ADR/reviewを渡す。
3. 各Agentは独立してレビューし、良かった点、改善点、重大リスク、6価値軸への影響、合否、次アクションを返す。
4. Review Orchestratorは指摘を統合し、重複、衝突、採用、保留、却下、追加調査を分類する。
5. 統合レビューを `docs/review/YYYYMMDD_xxx_review.md` に保存する。
6. 採用した改善は `docs/issue/` またはGitHub Issueへ接続する。
7. 重要判断はADRへ保存する。
8. 外部AIレビューが未実施の場合は、未実施理由と将来比較観点を残す。

## 入力境界とデータ保護

サブエージェントまたは外部AIへ渡す情報は、レビューに必要な最小範囲に限定する。

- 原則として対象Issue、対象ファイル、差分、関連ADR、関連レビューだけを渡す。
- secret、token、Authorization header、OAuth code、private key、cookie、database URL、webhook secretを渡さない。
- raw DM全文、不要PII、raw prompt、raw provider response、raw chain-of-thoughtを渡さない。
- 必要に応じてredaction済みの要約、safe metadata、対象行番号で代替する。
- 外部AIやL2レビューで機密性が高い情報を扱う場合は、data classification、redaction status、secret scan status、allowed tools/permissionsを記録する。
- 高信頼secret検出が `blocked` の場合は、リスク受容で通さず、AI送信、GitHub publish、exportを止める。
- Agent名や自己申告ロールだけを監査上の本人性として扱わない。将来DBやReview Centerへ保存する場合は、認証済みactor、対象commit、入力範囲、実行modeを記録する。

## 実行制御

サブエージェントレビューが遅い、途中で止まる、部分結果しか返らない場合でも、Security/QAのP0 blockerを迂回してはならない。

- Orchestratorは必須Agentと任意Agentを事前に分ける。
- 任意Agentが遅い場合は、理由を記録したうえでskipできる。
- 必須Agentが欠ける場合は、L1 fallbackで代替できるか、blockerにするかを記録する。
- 部分結果で進める場合は、欠落観点、fallback理由、残リスク、後続Issueを記録する。
- 外部AIレビュー未実施は、常にblockerにはしない。ただし、外部AI必須と定義したIssueでは未実施理由と判断を残す。

## 作業分割と停止防止

サブエージェント運用は品質を上げるための手段であり、作業を長時間停止させる目的ではない。Review Orchestratorは、以下を守る。

- すべてのIssueで全Agentを呼ばず、リスクに応じて必須Agentを選ぶ。
- P0/P1リスクが想定される領域を優先し、軽微な文言修正はL1で扱う。
- サブエージェントに渡す対象ファイル、責務、出力形式を小さく限定する。
- 並行できるレビューは並行し、統合判断だけをReview Orchestratorが行う。
- サブエージェントが失敗した場合は、L1 fallback、未実施理由、後続Issueのいずれかを記録する。

## ISSUE-005との接続

ISSUE-005は専門家AIレビューと評価保存パイプラインの基盤である。ISSUE-041はその運用を発展させ、専門家レビューをAgent単位へ分割し、Review Orchestratorが統合するためのgovernance layerとして扱う。

現時点の接続:

- `docs/review/` への保存ルールを継承する。
- 評価フレームワークの使い分けを `docs/evaluation/20260629_evaluation_frameworks.md` と整合させる。
- AIレビュー方針を `docs/ai/20260629_ai_agent_review_policy.md` から拡張する。

将来の接続:

- Review CenterでAgent別レビューを表示する。
- Agent出力をArtifact StoreまたはDBへ保存する。
- GitHub Issue、ADR、Roadmapへ改善アクションを自動接続する。

## 外部AI Adapter方針

外部AIを追加する場合も、Agent出力は `docs/evaluation/expert_review_schema.md` に合わせる。

- provider固有の生出力をそのまま採用しない。
- model/source、実行日時、入力概要、制約を記録する。
- secret、token、不要なPII、DM原文全文を外部AIへ渡さない。
- 外部AIが使えない場合は `not_available` とし、Codex一次レビューで進めるか、blockerにするかをOrchestratorが判断する。
- 外部AI間で意見が割れた場合は、差分と採用理由を統合レビューへ残す。

## Orchestrator統合ルール

Orchestratorは単純な多数決をしてはならない。以下の順で判断する。

1. セキュリティ、法務、データ保護、監査のP0指摘を最優先する。
2. API contract、DB migration、認証境界など後戻りコストが高い指摘を優先する。
3. Product価値とUXを損なう指摘は、技術的に通っていても保留しない。
4. 指摘が衝突した場合は、採用/保留/却下と理由を明記する。
5. 根拠のない高評価や、改善案のない批判は統合レビューで弱い根拠として扱う。
6. 修正可能な指摘はIssue化し、現Issue内で直すべきものと後続Issueへ送るものを分ける。

## 衝突分析

衝突は必ず記録する。

| 衝突例 | 判断方針 |
| --- | --- |
| Product OwnerがMVP短縮を求め、Securityが認証必須を求める | P0セキュリティを優先し、MVP範囲を再定義する |
| FrontendがUX簡略化を求め、QAが確認画面を求める | 誤操作影響が大きい場合はQAを優先する |
| CTOが共通化を求め、Tech Leadが過剰設計を懸念する | 変更頻度と重複量を根拠に判断する |
| AI Architectが自動化を求め、Product Managerが人間承認を求める | 監査対象workflowでは人間承認を優先する |

## 保存ルール

専門家サブエージェントレビューは、通常レビューと同じく `docs/review/` に保存する。

推奨ファイル名:

- `YYYYMMDD_expert_subagent_governance_review.md`
- `YYYYMMDD_expert_subagent_pilot_issue_XXX_review.md`
- `YYYYMMDD_<feature>_expert_subagent_review.md`

レビューには以下を含める。

- 評価日時
- 評価担当
- 使用フレームワーク
- 対象Issue
- 参加Agent
- Agent別サマリー
- 統合判定
- 衝突分析
- 良かった点
- 改善点
- 優先順位
- 次アクション
- Issue番号
- 外部AIレビュー状況

## 監査性

サブエージェント運用では、以下を可能な範囲で残す。

- Agent名
- Agentの責務
- 入力として渡したIssue/ファイル/前提
- 参照した主要docs
- 指摘の採用/保留/却下理由
- 外部AI未実施理由
- レビュー対象commitまたは変更範囲

raw chain-of-thoughtや不要な内部推論は保存しない。保存するのは、監査に必要な入力、出力要約、判断根拠、採用方針である。

## 失敗時の扱い

| 失敗 | 扱い |
| --- | --- |
| サブエージェントが起動できない | L1 role-separated reviewへ降格し、理由を記録する |
| 必須Agentレビューが欠けている | 次工程へ進めず、欠落Agentまたはfallback理由を記録する |
| Agent出力が曖昧 | Orchestratorが不採用または追加確認にする |
| Agent出力がschema-invalid | 完了条件を満たさないレビューとして扱う |
| Agent出力がlow confidence | 追加調査または別Agentレビューを要求する |
| Agent間で重大な衝突がある | 次工程へ進まず、衝突分析レビューを保存する |
| レビューがstale | 対象artifact更新後に再レビューする |
| 外部AIレビューが未実施 | Codex一次レビューとして保存し、外部レビュー待ちを明記する |
| 指摘がIssue化されない | レビュー未完了として扱う |

## ISSUE-039パイロット方針

初回パイロットはISSUE-039を対象にする。理由は、実認証/JWT actor identityがSpoofing、Repudiation、Elevation of Privilegeに直結するP0 blockerであり、専門家サブエージェントレビューの効果が出やすいためである。

必須Agent:

- Security Engineer Agent
- Backend Architect Agent
- Frontend Architect Agent
- QA Agent
- DevOps Agent
- CTO Agent
- Review Orchestrator

パイロットでは、実装前に以下を判定する。

- JWT/session方式ADRに十分な比較があるか
- `X-Actor-Id` をproduction pathから排除できるか
- OpenAPI security schemeとFrontend clientの契約が一致しているか
- AuditLog actor_idが認証済みuser idへ接続されるか
- request spec/E2Eが未認証、期限切れ、不正token、非memberを検証するか
- 再ログイン導線が日本語で安全に表示されるか
