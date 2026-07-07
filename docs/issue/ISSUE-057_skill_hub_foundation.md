# ISSUE-057: Codex継続利用向けSkill Hubを作成する

## Issue番号

ISSUE-057

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/84

## 背景

このプロジェクトでは `AGENTS.md` を最優先ルールとして、Issue駆動、API駆動、レビュー必須、日本語運用を徹底している。一方で、Codexが継続的に作業するうえで、API駆動開発、Rails、Next.js、レビュー、セキュリティ、プロダクト設計などを必要時に参照できるSkill Hubが必要になっている。

## 目的

既存 `AGENTS.md` と競合しない独自Skill Hubを `skills/` 配下に作成し、プロジェクト固有ルールを維持したまま専門スキルを追加しやすくする。

## 完了条件

- 指定された `skills/` ディレクトリ構成が作成されている
- 各 `SKILL.md` にPurpose、When to use、Inputs、Process、Output、Constraints、Checklistが含まれる
- Skill優先順位とroutingルールが明文化されている
- `skills/90-external` が参考情報専用として分離されている
- `AGENTS.md` への追記案が別文書として保存されている
- 既存 `AGENTS.md` を直接大きく書き換えていない
- レビュー結果が `docs/review/` に保存されている

## スコープ

- `skills/` 配下のSkill Hub初期構成
- `docs/ai/` へのSkill Hub設計文書
- `AGENTS.md` への追記案文書
- Issue台帳とレビュー文書

## 非スコープ

- 外部Agent-skillsの丸ごとコピー
- `AGENTS.md` 本体への直接追記
- CodexグローバルSkillディレクトリへのインストール
- NotebookLMや競合分析の詳細テンプレート実装

## 関連レビュー

- `docs/review/20260707_skill_hub_foundation_review.md`

## レビュー結果

実装前レビューで、Skill Hubは `AGENTS.md` を置き換えるものではなく、必要時に参照する補助レイヤーとして扱う方針を採用した。外部Skillは `skills/90-external` に隔離し、採用時は内容確認と再編集を必須にする。

## 次アクション

1. PRを作成し、差分確認を行う。
2. GitHub Issue #84へ検証結果をコメントする。
3. 必要であれば `AGENTS.md` 追記案の本体反映を別Issueで行う。

## 検証結果

- `find skills -name SKILL.md`: 22件
- frontmatterと必須7セクションの機械チェック: 成功
- `skill-creator/scripts/quick_validate.py`: 実行権限なし、Python経由ではPyYAML未導入により未完了
- `AGENTS.md`: 直接変更なし
