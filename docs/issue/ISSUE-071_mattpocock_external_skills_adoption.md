# ISSUE-071: mattpocock外部Skillの導入と運用整理

## Issue番号

- ローカルIssue: ISSUE-071
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/132

## 背景

Codexで継続利用するSkill Hubを整備済みであり、外部Agent-skillsは `skills/90-external/` で参考情報として分離する方針になっている。

ユーザーから `mattpocock/skills` の導入希望があり、既存の `AGENTS.md`、API駆動開発、Issue駆動開発、レビュー必須ルールと競合しない形でおすすめSkillを選定、導入、記録する必要がある。

## 目的

`mattpocock/skills` から、このプロジェクトの品質向上に寄与するSkillを選定してCodexグローバルSkillとして導入し、リポジトリ側には出典、採用理由、除外理由、競合時ルール、レビュー結果を残す。

## 完了条件

- おすすめSkillが `$CODEX_HOME/skills` へ導入されている。
- 導入Skill、除外Skill、採用理由が `skills/90-external/` に記録されている。
- 外部Skillが `AGENTS.md` より優先されないことが明記されている。
- 導入レビューが `docs/review/` に保存されている。
- GitHub IssueとローカルIssue台帳が同期されている。
- 外部Skill本体をリポジトリへ丸ごとコピーしていない。

## スコープ

- `mattpocock/skills` の内容確認
- 推奨Skillの選定
- CodexグローバルSkillへの導入
- 外部Skill参照記録の作成
- ローカルIssue台帳の作成
- 導入レビューの保存

## 非スコープ

- 外部Skillをプロジェクト固有Skillへ全面移植すること
- `AGENTS.md` の大幅な書き換え
- 外部Skillの内容を無審査で採用すること
- `mattpocock/skills` の全Skill導入

## 導入対象

- `tdd`
- `diagnosing-bugs`
- `codebase-design`
- `domain-modeling`
- `code-review`
- `research`
- `to-issues`

## 関連レビュー

- `docs/review/20260708_mattpocock_external_skills_adoption_review.md`

## レビュー結果

Codex、Tech Lead、AI Architect、Security Engineer、QA観点で一次レビューを実施した。採用Skillは開発品質、調査品質、Issue分割、レビュー品質を高める効果がある一方、外部Skillの一部表現はこのプロジェクトの自律運用、Rails責務分離、API駆動開発、レビュー保存ルールと衝突し得る。

そのため、外部SkillはグローバルCodex補助として導入し、リポジトリ内では `skills/90-external/mattpocock-skills/README.md` の補正方針に従って扱う。

## 優先度

P1

理由: Codexの作業判断に影響する運用基盤であり、競合ルールを曖昧にすると品質、セキュリティ、Issue駆動開発に影響するため。

## 次アクション

- Codexを再起動し、新規SkillがSkill一覧に出ることを確認する。
- 実作業で有用性が高いSkillは、内容を再編集してプロジェクト固有Skillへ昇格する。
- `to-prd` は要件定義フロー改善が必要になった段階で再評価する。
- Skill利用時は、必ず `AGENTS.md` と `skills/90-external/mattpocock-skills/README.md` の優先順位に従う。
