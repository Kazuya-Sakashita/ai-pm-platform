# 2026-07-07 CI Node.js 20 非推奨annotation解消レビュー

## 評価日時

2026-07-07 12:18:00 JST

## 評価担当

Codex（DevOps / Tech Lead / Security Engineer / QA）

## 使用フレームワーク

- G-STACK
- ISO25010
- DORA Metrics
- OWASP Top 10

## 対象Issue

- ISSUE-055
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/78

## 対象成果物

- `.github/workflows/ci.yml`
- `docs/issue/ISSUE-055_ci_node20_deprecation_annotation.md`

## 評価概要

PR #77のGitHub Actionsで、`actions/checkout@v4` と `actions/setup-node@v4` に対してNode.js 20 非推奨annotationが表示された。CIは成功していたが、将来のGitHub Actions runner変更で警告がリリース判断のノイズまたは互換性リスクになるため、最小変更でCI actionを現行majorへ更新する。

公式リリース確認時点で、`actions/checkout` の最新リリースは `v7.0.0`、`actions/setup-node` の最新リリースは `v6.4.0`、`actions/upload-artifact` の最新リリースは `v7.0.1` である。workflowでは既存方針に合わせ、majorタグの `actions/checkout@v7`、`actions/setup-node@v6`、`actions/upload-artifact@v7` を使用する。

## G-STACK

- Goal: CIのNode.js runtime annotationを解消し、リリース判定の信頼性を維持する。
- Strategy: アプリケーション実行バージョンや依存packageには触れず、GitHub Actionsの公式action majorのみ更新する。
- Tactics: `ci.yml` の `checkout`、`setup-node`、失敗時artifact保存actionを更新し、PR上の `verify` jobで確認する。
- Assessment: 変更範囲は小さいが、CI基盤に触れるためPR上のGitHub Actions実行を必須とする。
- Conclusion: 実装変更として妥当。ただしannotation解消はローカルでは判定できないため、GitHub Actions結果を完了条件に含める。
- Knowledge: 今後もCI警告はリリース判定で扱い、成功ログの警告を放置しない。

## 良かった点

- アプリケーションのNode.js version、npm package、Rails実装に影響を広げずに対応できる。
- GitHub公式actionの最新リリースを確認してから更新している。
- 既存のCI job構成、cache、`.node-version` 運用を維持している。
- 警告を別Issue化し、セキュリティ初期設計Issueの残課題から独立して追跡できている。

## 改善点

- GitHub Actionsのannotationはローカル検証では再現できないため、PR上のActionsログ確認が必須である。
- majorタグ運用は最新patchを取り込みやすい一方、厳密なサプライチェーン制御ではSHA pinningが望ましい。
- workflow actionの更新方針がADR化されておらず、将来のpinning方針が曖昧である。
- CI警告を自動検出してIssue化する仕組みはまだない。

## 改善案

- PRの `verify` jobで非推奨annotationが解消されたことを確認し、GitHub Issue #78へ検証結果をコメントする。
- production release前に、GitHub Actionsのaction pinning方針をDevOps/Security観点でADR化する。
- 将来、CIログannotationの定期棚卸しをrelease checklistへ追加する。
- 重要workflowでは、major tag運用からSHA pinningへ移行するかを別Issueで判断する。

## 優先順位

- P0: PR上の `verify` job成功と非推奨annotation解消確認。
- P1: GitHub Issue #78への検証結果記録。
- P2: action pinning方針のADR化。
- P2: CI annotation棚卸しのrelease checklist追加。

## 次アクション

1. `ci.yml` を更新する。
2. `npm run display:check` と `git diff --check` を実行する。
3. PRを作成し、GitHub Actions `verify` jobを確認する。
4. annotation解消が確認できたらGitHub Issue #78をクローズする。

## Issue番号

- ISSUE-055
- GitHub Issue #78

## 判定

条件付き合格。PR上のGitHub Actionsで `verify` jobが成功し、Node.js 20 deprecated annotationが出ないことを確認できれば、ISSUE-055はクローズ可能。
