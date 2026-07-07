# AGENTS.md 追記案: Skill Hub運用

以下は `AGENTS.md` の末尾に追記できる案である。現時点では本体へは反映せず、確認用の提案として保存する。

```md
## Skill Hub運用

このリポジトリでは、Codexが必要な専門手順だけを参照できるように `skills/` 配下へ独自Skill Hubを置く。

### 目的

- `AGENTS.md` を最優先ルールとして維持する。
- API駆動開発、Rails、Next.js、OpenAPI、RSpec、レビュー、セキュリティ、プロダクト設計などを必要時に参照できるようにする。
- 外部Skillをそのまま混ぜず、参考情報として隔離する。
- Codexが迷わず使えるように、作業前のSkill選択ルールを明確にする。

### 優先順位

1. システム指示、開発者指示、ユーザー明示指示
2. `AGENTS.md`
3. `skills/00-core`
4. 関連するプロジェクト固有Skill
5. `docs/` のIssue、ADR、レビュー、設計文書
6. `skills/90-external` の参考情報

`AGENTS.md` とSkillが矛盾した場合は、必ず `AGENTS.md` を優先する。

### Skillの使い分け

- 作業開始時に迷う場合は `skills/00-core/skill-routing/SKILL.md` を確認する。
- 実装方針や分割に迷う場合は `skills/00-core/coding-principles/SKILL.md` を確認する。
- API駆動の実装では `skills/10-development/api-driven-development/SKILL.md` を確認する。
- Rails実装では `skills/10-development/rails-backend/SKILL.md` を確認する。
- Next.js実装では `skills/10-development/nextjs-frontend/SKILL.md` を確認する。
- OpenAPI更新では `skills/10-development/openapi/SKILL.md` を確認する。
- RSpec追加では `skills/10-development/rspec/SKILL.md` を確認する。
- レビュー時は `skills/20-review/` の該当Skillを確認する。
- GitHub Issue、PR、release gateでは `skills/40-workflow/` の該当Skillを確認する。

### 外部Skillの扱い

- `skills/90-external` は参考情報置き場としてのみ扱う。
- 外部Agent-skillsを丸ごとコピーしない。
- 外部Skillを採用する場合は、内容を確認し、このプロジェクト用に再編集してから取り込む。
- 出典不明、保守不能、既存ルールと矛盾する外部Skillは採用しない。

### 競合時の判断ルール

- `AGENTS.md`、Issue、ADR、レビュー文書、OpenAPI contractの順に根拠を確認する。
- 競合が解消できない場合は、レビュー文書に判断理由を残す。
- セキュリティ、認証、認可、監査、個人情報、秘密情報に関する競合はSecurity Engineer視点のレビューを必須にする。

### Codexが作業前に参照すべきSkillの選び方

1. まず今回の作業フェーズを確認する。
2. `skills/00-core/skill-routing/SKILL.md` で参照すべきSkillを選ぶ。
3. Issue、OpenAPI、レビュー、実装、テスト、PRの順序が必要な場合はAPI駆動Skillを優先する。
4. 作業が複数領域にまたがる場合は、最小限のSkillだけ読む。
5. Skillを読んでも `AGENTS.md` と矛盾する場合は、Skillではなく `AGENTS.md` を採用する。
```
