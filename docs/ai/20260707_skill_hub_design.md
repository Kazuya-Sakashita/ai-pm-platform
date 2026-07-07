# 2026-07-07 Skill Hub設計

## 目的

このSkill Hubは、CodexがAI PM Platformで継続作業するときに、必要な専門手順だけを短く参照できるようにするための補助知識ベースである。

`AGENTS.md` を最優先ルールとして維持し、Skillはそれを置き換えない。Skillは、API駆動開発、Rails、Next.js、RSpec、レビュー、セキュリティ、プロダクト設計、GitHub運用、調査資料化などの作業時に参照する。

## 優先順位

1. システム指示、開発者指示、ユーザー明示指示
2. `AGENTS.md`
3. `skills/00-core`
4. 関連するプロジェクト固有Skill
5. `docs/` の設計、ADR、Issue、レビュー
6. `skills/90-external` の参考情報

`skills/90-external` は参考情報としてのみ扱う。外部Skillと既存ルールが矛盾した場合は、既存ルールを優先する。外部Skillを採用する場合は、内容を確認し、このプロジェクト用に再編集してから取り込む。

## ルーティング

- 作業開始時は `skills/00-core/skill-routing/SKILL.md` を確認する。
- 実装全般では `skills/00-core/coding-principles/SKILL.md` を確認する。
- AI Agent、外部AI、専門家サブエージェントを扱う場合は `skills/00-core/ai-agent-policy/SKILL.md` を確認する。
- API contract、Backend、Frontend、テストの順序が関係する場合は `skills/10-development/api-driven-development/SKILL.md` を確認する。
- Rails実装では `rails-backend`、Next.js実装では `nextjs-frontend`、OpenAPI更新では `openapi`、RSpecでは `rspec` を確認する。
- レビュー依頼や完了前評価では `skills/20-review/` の該当Skillを確認する。
- 企画、MVP、UX、競合分析では `skills/30-product/` を確認する。
- GitHub Issue、PR、release gateでは `skills/40-workflow/` を確認する。
- NotebookLM、プレゼン、文書要約では `skills/50-research/` を確認する。

## 既存ルールとの競合確認

- `AGENTS.md` 本体は変更せず、追記案だけを別ファイルに保存する。
- Issueなし実装禁止、レビュー必須、API駆動、日本語運用はSkill側でも制約として維持する。
- 外部Skillはコピーせず、`90-external` に参考情報置き場だけ作る。
- Skillは大きくしすぎず、各 `SKILL.md` を必要時に読める短さにする。

## 今後の拡張

- NotebookLM入力資料作成Skill
- Figma / 画面設計レビューSkill
- Playwright visual QA Skill
- GitHub App live smoke Skill
- OpenAI Structured Outputs設計Skill
- SaaS価格戦略Skill
- リリースノート生成Skill
