# 2026-07-07 サブエージェント運用ポリシーレビュー

## 評価日時

2026-07-07 15:25:00 JST

## 評価担当

Codex Review Orchestrator

参加Agent:

- Security Engineer Agent
- Product Manager / UI/UX Designer Agent
- CTO / Tech Lead / QA Agent

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- HEART
- RICE

## 対象Issue

- ISSUE-058
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/86

## 対象成果物

- `AGENTS.md`
- `docs/ai/expert_subagents.md`
- `docs/evaluation/expert_review_schema.md`
- `skills/00-core/ai-agent-policy/SKILL.md`
- `skills/00-core/skill-routing/SKILL.md`
- `skills/20-review/security-review/SKILL.md`
- `docs/issue/ISSUE-058_subagent_operating_policy.md`

## 評価概要

ユーザーが提示したサブエージェント運用ポリシーは、既存の専門家サブエージェントレビュー運用と矛盾しない。既存運用を置き換えるのではなく、全Agent共通の6価値軸として追加することで、セキュリティ、品質、UX、継続利用、事業価値、長期運用を同時に評価できる。

## G-STACK

- Goal: 専門サブエージェント運用を、セキュリティ最優先かつ長期価値重視のレビュー基盤へ強化する。
- Strategy: `AGENTS.md` には短い共通原則を置き、詳細は `docs/ai/expert_subagents.md` とschema、Skillへ分散する。
- Tactics: 6価値軸、Security/QA P0 blocker、作業分割、外部AI未実施時のfallbackを明記する。
- Assessment: 既存のL1/L2/L3、専門Agent、Review Orchestrator方針と整合している。
- Conclusion: 条件付き合格。実運用で6価値軸が形骸化しないよう、レビューschemaとSkillから参照できるようにした。
- Knowledge: サブエージェントは全Issueで大量起動するものではなく、リスクに応じて選ぶ。

## Agent別サマリー

### Security Engineer Agent

- 判定: conditional_pass
- 良かった点: Security by Design、OWASP、STRIDE、最小権限、監査ログ、秘密情報管理を共通評価軸に入れる方針は妥当。
- 改善点: Security P0 blockerを単なる推奨ではなくフェーズゲートとして明記し、入力最小化、redaction、secret scan、allowed tools、risk acceptanceを監査できるようにする必要がある。
- 採用方針: `AGENTS.md`、`docs/ai/expert_subagents.md`、`docs/evaluation/expert_review_schema.md`、`ai-agent-policy`、`security-review` Skillへ反映した。

### Product Manager / UI/UX Designer Agent

- 判定: conditional_pass
- 良かった点: 技術評価だけでなく、ユーザー満足度、継続利用、事業価値を共通評価軸に含める点はAI PM Platformの差別化につながる。
- 改善点: 全Issueで全Agentを起動すると速度と運用負荷が悪化するため、軽量IssueではL1でよいことを明記する必要がある。
- 採用方針: `docs/ai/expert_subagents.md` にユーザー導線、継続利用、主要業務フロー、導入価値の起動条件と、作業分割、停止防止を追加した。

### CTO / Tech Lead / QA Agent

- 判定: conditional_pass
- 良かった点: 技術品質、テスト容易性、長期運用を共通評価軸へ入れることで、実装可能性だけの合格を防げる。
- 改善点: schemaに6価値軸と実行状態、fallback理由、欠落Agent、部分結果の扱いがないとレビュー結果の比較や保存が不安定になる。
- 採用方針: `docs/evaluation/expert_review_schema.md` に `value_axis_assessment`、`execution`、`data_handling` を追加した。

## 統合判定

条件付き合格。

今回の変更は既存ルールと競合せず、むしろ `AGENTS.md` の完成条件、専門家サブエージェントレビュー運用、Skill Hubの `ai-agent-policy` を補強する。ただし、今後の実Issueで6価値軸を形式的なチェックにしないため、重要Issueではレビュー文書にAgent別サマリーと統合判定を残す必要がある。

## 衝突分析

| 論点 | 衝突 | 判断 |
| --- | --- | --- |
| セキュリティ最優先とMVP速度 | Security P0を優先するとMVPが遅くなる可能性がある | P0は次工程ブロック。MVPは範囲を調整して守る。 |
| 全Agentレビューと作業速度 | 全Issueで全Agentを呼ぶと停止時間が増える | L1/L2/L3を使い分け、必須Agentを絞る。 |
| AGENTS.mdとSkill Hub | Skill側で詳細を書きすぎると最優先ルールが曖昧になる | AGENTSは原則、docsとSkillは運用詳細に分ける。 |

## 良かった点

- 既存の専門家サブエージェント運用を置き換えず、共通評価軸として追加している。
- Security/QA P0 blockerの扱いを維持しつつ、ユーザー価値と事業価値も評価対象にできている。
- Codexが作業時に参照するSkillにも反映し、ドキュメントだけで終わらせていない。
- 作業を小さく分ける方針を追加し、長時間停止のリスクを下げている。
- 入力境界、redaction、secret scan、allowed tools、risk acceptanceをschemaで記録できるようにした。

## 改善点

- 6価値軸のスコアリング基準はまだ定性的である。
- Review CenterやDB保存へ接続する実装は未着手である。
- 外部AIレビューとの比較運用は、外部AI利用可能性に依存する。
- data handling項目は推奨監査項目であり、既存レビューへの一括適用は未実施である。

## 優先順位

- P0: Security/QA P0 blockerを次工程ブロックとして維持する。
- P1: 6価値軸をschema、docs、Skillへ反映する。
- P1: 全Issueで全Agentを呼ばない停止防止ルールを明記する。
- P1: 入力境界、redaction、secret scan、risk acceptanceを推奨監査項目として追加する。
- P2: 将来、6価値軸の定量rubricを追加する。

## 次アクション

1. 差分検証を行う。
2. PRを作成し、CI結果を確認する。
3. 今後の重要Issueで6価値軸を使ったレビュー例を追加する。
4. 必要に応じて6価値軸rubricを後続Issue化する。

## 検証結果

- `git diff --check`: 成功
- Skill Hub必須セクション確認: 22件成功
- `npm run api:verify`: 成功
- `npm run display:check`: 成功
- `npm run verify`: ルートにscript未定義のため未実行

## Issue番号

- ISSUE-058
- GitHub Issue #86

## 外部AIレビュー状況

- status: not_available
- notes: この環境ではClaude、ChatGPTなど外部AIの独立実行は未実施。Codexサブエージェントによる一次レビューとして保存する。
