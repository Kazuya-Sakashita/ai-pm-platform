---
name: skill-routing
description: AI PM PlatformのSkill Hubで、どのSkillをいつ読むか判断するためのルーティングSkill。作業開始時、参照Skillに迷うとき、AGENTS.mdとSkillの優先順位を確認するときに使う。
---

# Skill Routing

## Purpose

作業に必要なSkillだけを選び、`AGENTS.md` と競合しない形で参照する。

## When to use

- 作業開始時。
- どのSkillを読むべきか迷うとき。
- 外部Skillや参考情報を取り込む前。

## Inputs

- ユーザー依頼。
- 対象Issue、作業フェーズ、変更対象。
- 既存 `AGENTS.md` と関連docs。

## Process

1. 最初に `AGENTS.md` の優先を確認する。
2. 共通判断は `skills/00-core` を読む。
3. 実装なら `skills/10-development` から最小限を選ぶ。
4. レビューなら `skills/20-review` を選ぶ。
5. 企画や競合なら `skills/30-product` を選ぶ。
6. GitHubやreleaseなら `skills/40-workflow` を選ぶ。
7. 調査、要約、資料化なら `skills/50-research` を選ぶ。
8. `skills/90-external` は参考としてのみ扱う。

## Output

- 参照するSkill一覧。
- 参照しないSkillの理由。
- 競合がある場合の判断根拠。

## Constraints

- 必要以上にSkillを読まない。
- 外部Skillをそのまま採用しない。
- Skillが `AGENTS.md` と矛盾したら `AGENTS.md` を優先する。

## Checklist

- [ ] `AGENTS.md` を優先した。
- [ ] 参照Skillを最小限にした。
- [ ] 外部Skillを参考扱いにした。
- [ ] 競合時の判断理由を残した。
