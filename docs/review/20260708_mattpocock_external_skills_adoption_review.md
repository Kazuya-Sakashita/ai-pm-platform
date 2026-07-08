# mattpocock外部Skill導入レビュー

## 評価日時

2026-07-08 20:15:50 JST

## 評価担当

- Codex
- Tech Lead
- AI Architect
- Security Engineer
- QA

## Issue番号

- ISSUE-071
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/132

## 対象

- `mattpocock/skills`
- `skills/90-external/mattpocock-skills/README.md`
- `$CODEX_HOME/skills/tdd`
- `$CODEX_HOME/skills/diagnosing-bugs`
- `$CODEX_HOME/skills/codebase-design`
- `$CODEX_HOME/skills/domain-modeling`
- `$CODEX_HOME/skills/code-review`
- `$CODEX_HOME/skills/research`
- `$CODEX_HOME/skills/to-issues`

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- MoSCoW

## 良かった点

- 外部Skillをリポジトリへ丸ごとコピーせず、CodexグローバルSkillとプロジェクト内の参照記録に分離した。
- TDD、バグ診断、設計、ドメインモデリング、レビュー、調査、Issue分割に絞って導入し、開発運用への即効性を優先した。
- 個人運用色が強いSkill、未完成Skill、既存フローと衝突しやすいSkillを除外した。
- `AGENTS.md` とプロジェクト固有Skillを優先するルールを明記した。
- MIT Licenseと確認コミットを記録し、出典の追跡可能性を確保した。

## 改善点

- グローバルSkillはCodex再起動後に自動候補へ出るため、外部Skillの指示がプロジェクトルールより強く見える可能性がある。
- 導入元リポジトリの更新により、将来的に内容が変わる可能性がある。
- `tdd` や `to-issues` の一部手順は、このプロジェクトの自律実行、Issue台帳、GitHub同期ルールと完全一致しない。
- 現時点では導入Skillの実プロジェクト利用実績がまだ少ない。

## 改善案

- Skill利用時は、最初に `AGENTS.md` と `skills/90-external/mattpocock-skills/README.md` の補正方針を確認する。
- 有用性が高いSkillは、外部本文をそのまま使わず、プロジェクト固有Skillへ再編集して昇格する。
- 導入元の更新を取り込む場合は、再度レビューを作成し、差分と競合有無を確認する。
- セキュリティ、認証、監査、秘密情報管理に関わる作業では、外部Skillより Security Engineer レビューと `AGENTS.md` を優先する。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | なし | 直ちに停止すべきセキュリティまたは品質上の問題はない |
| P1 | 外部Skillの優先順位と補正方針を明文化する | Codexの作業判断に直接影響するため |
| P2 | 実利用後にプロジェクト固有Skillへ昇格する | 汎用Skillをそのまま使い続けると運用差分が残るため |
| P3 | `to-prd` など保留Skillを再評価する | 要件定義フロー改善時に価値が出る可能性があるため |

## G-STACK

### Goal

外部Skillを安全に導入し、AI PMプラットフォームの開発品質、レビュー品質、調査品質、Issue分割品質を高める。

### Strategy

外部Skill本体はCodexグローバル領域へ導入し、リポジトリには出典、採用理由、除外理由、競合時ルールだけを残す。

### Tactics

- 推奨Skillを7件に絞る。
- 個人用、未完成、既存フローと衝突しやすいSkillを除外する。
- `skills/90-external/` に導入記録を保存する。
- `docs/issue/` と `docs/review/` に運用判断を保存する。

### Assessment

導入方針は妥当。ただし、Codex再起動後に外部Skillが自動候補へ出るため、作業ごとの優先順位確認が必要。

### Conclusion

採用可。正式なプロジェクトルールではなく、補助Skillとして限定運用する。

### Knowledge

`mattpocock/skills` はMIT Licenseで公開されており、2026-07-08時点の確認コミットは `896f14d9c25659f03b24e08e4efc3ee69bbade08` である。

## STRIDE観点

| 観点 | リスク | 対応 |
| --- | --- | --- |
| Spoofing | 外部Skill由来の指示をプロジェクト公式ルールと誤認する | `skills/90-external/` で参考扱いと明記 |
| Tampering | 導入元更新で内容が変わる | 確認コミットを記録し、更新時に再レビュー |
| Repudiation | Skill導入判断の根拠が残らない | Issue、レビュー、導入記録を保存 |
| Information Disclosure | ログやsecretを外部Skill手順で不用意に記録する | secret、token、不要PII、raw chain-of-thought保存禁止を明記 |
| Denial of Service | 過剰な確認待ちや大型Skill読み込みで作業が止まる | 小さく分割し、自律実行できる範囲は継続 |
| Elevation of Privilege | 外部Skillが `AGENTS.md` より優先される | 優先順位ルールで明確に禁止 |

## ISO25010観点

- 保守性: 導入記録と補正方針により維持しやすい。
- 互換性: 既存Skill Hubと分離しているため競合を限定できる。
- セキュリティ: 外部Skillを参考扱いにし、秘密情報管理の制約を明記した。
- 使用性: Codexが必要時に参照しやすい粒度で記録した。
- 信頼性: 確認コミット、ライセンス、Issue、レビューを紐付けた。

## MoSCoW

| 区分 | 内容 |
| --- | --- |
| Must | `tdd`、`diagnosing-bugs`、`code-review`、`to-issues` の安全な導入 |
| Should | `codebase-design`、`domain-modeling`、`research` の導入 |
| Could | `to-prd` の再評価 |
| Won't | 個人用、未完成、既存運用と衝突しやすいSkillの常用化 |

## 次アクション

- Codexを再起動して、新規Skillが一覧に表示されることを確認する。
- 実利用時に有用だったSkillをプロジェクト固有Skillへ再編集する。
- 外部Skill更新を取り込む場合は、差分レビューを作成する。

## 検証結果

- `mattpocock/skills` のLicenseがMITであることを確認した。
- 導入対象7件が `$CODEX_HOME/skills` 配下に存在することを確認した。
- 外部Skill本体をリポジトリへ丸ごとコピーしていないことを確認した。

## 結論

条件付きで導入可。世界レベルのSaaSを目指す品質基準では、外部Skillをそのまま信頼するのではなく、プロジェクト固有ルールへ適合させながら段階導入する必要がある。
