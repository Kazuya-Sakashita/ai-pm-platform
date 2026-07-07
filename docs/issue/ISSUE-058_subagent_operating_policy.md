# ISSUE-058: サブエージェント運用ポリシーを6価値軸で強化する

## Issue番号

ISSUE-058

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/86

## 背景

このプロジェクトでは、専門家サブエージェントレビュー運用とSkill Hubを導入済みである。今後は、単にコードが動くかではなく、強固なセキュリティ、高い技術品質、優れたユーザー体験、継続利用、事業価値、長期運用の6項目を全Agent共通の判断基準として明確化する必要がある。

## 目的

既存の `AGENTS.md`、`docs/ai/expert_subagents.md`、`docs/evaluation/expert_review_schema.md`、Skill Hubと競合しない形で、サブエージェント運用ポリシーを強化する。

## 完了条件

- 6つの共通評価軸が明文化されている。
- Security by Design、OWASP Top 10、最小権限、認証、認可、入力値検証、監査ログ、秘密情報管理が反映されている。
- ユーザー、開発者、運営者の三者にとって長期的な価値があるかを判断基準に含めている。
- 既存の専門家サブエージェント運用、レビューschema、Skill Hub優先順位と競合しない。
- 必要なレビュー結果が `docs/review/` に保存されている。
- GitHub Issue、ローカルIssue台帳、PRが日本語で管理されている。

## スコープ

- `AGENTS.md` への最小追記
- `docs/ai/expert_subagents.md` の運用方針追記
- `docs/evaluation/expert_review_schema.md` の6価値軸追記
- `skills/00-core/ai-agent-policy/SKILL.md` の更新
- `skills/00-core/skill-routing/SKILL.md` の更新
- `skills/20-review/security-review/SKILL.md` の更新
- レビュー文書の作成

## 非スコープ

- 外部AI provider実装
- API、DB、UIの機能追加
- 既存レビュー履歴の大規模な再編集
- 全Issueへの過去レビュー再適用

## 関連レビュー

- `docs/review/20260707_subagent_operating_policy_review.md`

## レビュー結果

Security、Product/UX、CTO/Tech Lead/QA観点のサブエージェントレビューを実施し、Review Orchestratorが統合する。セキュリティ最優先と作業停止防止を両立するため、6価値軸は全Agent共通の最低評価軸として扱い、全Issueで全Agentを呼ぶ運用にはしない。

## 次アクション

1. サブエージェントレビュー結果を統合する。
2. 変更差分とSkill構造を検証する。
3. PRを作成し、CI結果を確認する。

## 検証結果

- `git diff --check`: 成功
- Skill Hub必須セクション確認: 22件成功
- `npm run api:verify`: 成功
- `npm run display:check`: 成功
- `npm run verify`: ルートにscript未定義のため未実行
