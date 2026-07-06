# 2026-07-06 Requirement生成品質baselineレビュー

## 評価日時

2026-07-06 20:06:03 JST

## 評価担当

Codex as AI Architect / Product Manager / Tech Lead / Security Engineer / QA

## Issue番号

GitHub Issue #3

## 対象成果物

- `docs/evaluation/fixtures/requirement_generation/cases.json`
- `scripts/evaluate-requirement-generation.rb`
- `docs/evaluation/20260706_requirement_generation_baseline.md`
- `backend/spec/scripts/evaluate_requirement_generation_spec.rb`
- `package.json`

## 使用フレームワーク

- G-STACK
- ISO25010
- MoSCoW
- STRIDE
- QA観点のfixture評価

## 評価サマリー

Requirement生成品質評価セットをfixture化し、現行deterministic providerに対するbaselineを取得した。平均点は91.0 / 100、各ケースは78点以上であり、構造化、受け入れ条件、未決事項抽出は一定水準に達している。

一方で、P0観点の未達が6件残っているため、世界レベルSaaS基準ではIssue #3を完了扱いにできない。特に「明示された非スコープをRequirementへ確実に反映する力」と「セキュリティ、PII、secret、監査、運用要件を会議文脈に応じて抽出する力」が不足している。

## G-STACK評価

### Goal

承認済みMinutesから生成したRequirement draftが、Issue生成とOpenAPI設計へ進めるだけの品質かを自動判定できる状態にする。

### Strategy

サンプルMinutes、期待語、最小件数、禁止pattern、P0カテゴリをJSON fixtureとして固定し、現行providerを同一条件で評価できるようにした。

### Tactics

- 6ケースのfixtureを作成した
- 100点満点のrubricをスクリプト化した
- `npm run requirements:evaluate` で再実行できるようにした
- baseline reportをMarkdownで保存した
- 評価器のRSpecを追加した

### Assessment

平均91.0点であり、構造と検証可能性は良い。ただしP0未達が残るため、CI blocking gateへ昇格する前にprovider改善が必要である。

### Conclusion

評価基盤としては採用可能。Requirement生成機能そのものはP0未達のため、次工程へ無条件に進めない。

### Knowledge

deterministic providerは会議内の決定、action item、open questionを素直に構造化する用途には強い。一方、明示的な「MVP外」「運用要件」「セキュリティ要件」を抽出、分類、補強する能力は弱い。

## 良かった点

- 評価セットが文書だけでなく、実行可能なfixtureとスクリプトになった。
- baselineを保存したことで、今後のprovider改善やOpenAI provider導入時に退行を検知できる。
- Critical failureは0件で、会議にない危険な断定や禁止patternの生成は確認されなかった。
- `--enforce` を用意したため、将来CIでwarningからblockingへ段階的に移行できる。
- RSpecで評価器の基本動作と禁止pattern検出を確認できる。

## 改善点

- CASE-RQ-003でSSOの非スコープ抽出ができず、セキュリティ/PII/secret/権限の非機能要件が不足している。
- CASE-RQ-004でBackend、Frontend、実装を非スコープとして明示できていない。
- CASE-RQ-005で情報不足時の非スコープを十分に固定できていない。
- CASE-RQ-006でCI警告、差分確認、レビュー容易性、監査性の非機能要件が不足している。
- 現状の評価は期待語ベースであり、意味的に正しいが表現ゆれした出力を過小評価する可能性がある。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | out_of_scope抽出を独立処理として強化する | 非スコープを落とすと過剰実装とIssue誤生成につながる |
| P0 | Security/Operations/UXの非機能要件チェックリストをproviderへ追加する | PII、secret、監査、CI品質劣化はAI PMの信頼性に直結する |
| P1 | baselineをCI warningとして実行する | 退行検知を早く始められるが、現時点ではblockingには早い |
| P1 | OpenAI provider導入時に同fixtureで比較する | deterministic providerとの差分を品質判断に使う |
| P2 | 期待語評価に加え、人間レビューまたはLLM judgeを併用する | 表現ゆれと文脈評価の精度を上げる |

## 次アクション

- deterministic providerに、非スコープ抽出専用ロジックを追加する。
- Security/PII/secret/監査/権限/CI/UXを非機能要件候補として抽出するruleを追加する。
- `npm run requirements:evaluate -- --enforce` はまだCI blockingにしない。まずwarning扱いで運用する。
- provider改善後にbaselineを再取得し、P0未達0件になった時点でIssue #3のクローズ可否を再評価する。

## 判定

条件付き合格。

評価基盤の追加は完了。ただしRequirement生成品質そのものはP0未達が残るため、Issue #3は継続する。
