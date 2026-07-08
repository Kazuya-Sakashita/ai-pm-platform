# mattpocock/skills 導入記録

## 出典

- Repository: https://github.com/mattpocock/skills
- 確認日: 2026-07-08
- 確認コミット: `896f14d9c25659f03b24e08e4efc3ee69bbade08`
- License: MIT License
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/132
- 関連レビュー: `docs/review/20260708_mattpocock_external_skills_adoption_review.md`

## 導入方針

`mattpocock/skills` は、CodexグローバルSkillとして `$CODEX_HOME/skills` へ導入する。

このリポジトリでは、外部Skillをそのままプロジェクトルールとして扱わない。`AGENTS.md`、`skills/00-core`、プロジェクト固有Skillを優先し、外部Skillは作業品質を上げるための補助参照として扱う。

## 今回導入したSkill

| Skill | 用途 | このプロジェクトでの扱い |
| --- | --- | --- |
| `tdd` | テスト駆動の小さい実装ループ | RSpec、Playwright、API駆動開発の既存ルールへ合わせて使う |
| `diagnosing-bugs` | バグ調査、再現、仮説検証 | Issue、レビュー、監査ログの運用と組み合わせる |
| `codebase-design` | 深いモジュール、小さいインターフェース、責務分離 | Rails責務分離、DDD、OpenAPI境界の補助観点として使う |
| `domain-modeling` | 用語、概念、ドメイン関係の整理 | `docs/product/`、`docs/decisions/`、OpenAPI設計へ反映する |
| `code-review` | 仕様準拠と品質基準のレビュー | `docs/review/` の必須項目、専門家レビュー体制へ統合する |
| `research` | 一次情報ベースの調査 | 市場調査、競合分析、技術調査で出典付き記録に使う |
| `to-issues` | 作業を小さいIssueへ分割 | `docs/issue/` とGitHub Issue同期の補助として使う |

## 除外したSkill

| Skill群 | 除外理由 |
| --- | --- |
| `ask-matt`、`personal/*` | 個人運用色が強く、このプロジェクト固有ルールとして不適切 |
| `in-progress/*` | 未完成扱いで、安定運用ルールとして採用しない |
| `implement`、`prototype` | Issue駆動、API駆動、レビュー必須フローと衝突しやすい |
| `grill*`、`teach` | 対話・教育用途が中心で、現時点の開発運用優先度が低い |
| `setup-*`、`migrate-*` | 環境セットアップ依存が強く、既存Skill Hub構成と重複する |
| `to-prd` | 既存の要件定義、レビュー、Issue化フローと重なるため今回は保留 |
| `triage`、`resolving-merge-conflicts` | 必要時に単発参照すれば十分で、常用Skillとしては優先度が低い |

## 競合時の判断ルール

1. `AGENTS.md` を最優先する。
2. 次に `skills/00-core` を優先する。
3. プロジェクト固有Skillを外部Skillより優先する。
4. `mattpocock/skills` は参考情報として扱い、矛盾する指示は採用しない。
5. 外部Skillの一部を正式採用する場合は、内容を確認し、このプロジェクト向けに再編集してから `skills/` 配下へ追加する。
6. secret、token、不要なPII、raw chain-of-thoughtを外部Skill由来の記録へ保存しない。

## Skill別の補正方針

- `tdd`: 「ユーザー確認を待つ」手順が含まれる場合でも、このプロジェクトではリスクが低い範囲は自律的に進める。RSpecでは `let!` 基本方針を守る。
- `diagnosing-bugs`: 再現と仮説検証は採用する。ログ、監査情報、秘密情報をレビュー文書へそのまま貼らない。
- `codebase-design`: 抽象化の考え方は採用する。ただし Rails のService、Policy、Query、Serializer、API境界など既存用語を置き換えない。
- `domain-modeling`: 用語整理は採用する。`CONTEXT.md` を新設せず、既存の `docs/product/`、`docs/decisions/`、`docs/api/` へ反映する。
- `code-review`: Standards / Spec の観点は採用する。最終レビューは `AGENTS.md` の必須項目と専門家レビュー形式へ合わせる。
- `research`: 一次情報、公式ドキュメント、出典URLを重視する。最新性が必要な内容は必ず確認する。
- `to-issues`: 垂直スライス化は採用する。Issue登録、`docs/issue/`、GitHub同期を省略しない。

## 運用メモ

導入済みSkillをCodexが自動認識するには、Codexセッションの再起動が必要になる場合がある。再起動後も、このリポジトリでは本ファイルと `AGENTS.md` の優先順位を前提に使う。
