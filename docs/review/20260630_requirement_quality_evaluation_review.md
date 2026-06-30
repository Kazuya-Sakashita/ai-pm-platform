# 2026-06-30 Requirement生成品質評価セットレビュー

## 評価日時

2026-06-30 18:50 JST

## 評価担当

Codex as Product Manager / AI Architect / QA / Security Engineer / Tech Lead

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## 使用フレームワーク

- G-STACK
- ISO25010
- MoSCoW
- STRIDE

## 評価対象

- `docs/evaluation/20260630_requirement_generation_quality_eval.md`
- Issue #3「議事録から要件定義ドラフトを生成する」のP0未完了項目「Requirement生成品質評価セット」

## 良かった点

- Requirement生成品質を「よさそう」ではなく、100点rubric、合格基準、Critical failureで判定できる形にした。
- 対象出力項目がOpenAPIのRequirement schemaと概ね対応しており、Issue生成とOpenAPI設計に進める粒度を確認できる。
- サンプルケースがhappy pathだけでなく、矛盾、機微情報、情報不足、API駆動開発、UX/運用要件を含んでいる。
- 失敗時の改善アクションがprompt、review、security、scope control、自動化に分かれており、次の改善Issueに落としやすい。
- レビューなしで次工程へ進まないというAGENTS.mdのルールを、合格基準とCritical failureへ反映している。

## 改善点

- 評価セットはまだ文書であり、実行可能fixture、golden dataset、採点スクリプトはない。
- 現行deterministic providerや将来のOpenAI providerに対する実測スコアが未取得で、baselineがない。
- 根拠追跡性やconfidenceは評価対象に含めたが、現行Requirement schemaには明示フィールドがないため、レビュー補助情報としてしか扱えない。
- 人間レビュアー間の採点ばらつき、外部AIレビューとの差分比較、採点校正手順が未定義。
- CI gateは案に留まり、どのタイミングでwarningからblockingへ昇格するかの運用責任者が未定である。

## 優先順位

1. P0: この評価セットをfixture化し、CASE-RQ-001からCASE-RQ-006の期待出力を保存する
2. P0: 現行Requirement生成providerで初回採点を実施し、baseline scoreをレビューに追記する
3. P0: Requirement承認APIとReview gateに、品質評価未達時の停止条件を接続する
4. P1: 根拠追跡性、confidence、prompt versionの保存方法をAPI/DB設計で再評価する
5. P1: LLM judgeと人間レビューの差分を比較し、採点基準を校正する

## 次アクション

- Issue #3は「品質評価セットの文書化」は前進したが、実行可能評価、承認API、Issue/OpenAPI生成条件との接続が残るためopen継続にする。
- Issue #4へ進む前に、Requirement approved状態と品質評価基準を次工程のgateへ接続する。
- Issue #5のAIレビュー/評価保存パイプラインと連携し、scorecard保存先を決める。

## Issue番号

- GitHub Issue: #3

## G-STACK

### Goal

Requirement draftがIssue生成とOpenAPI設計に進める品質かを、レビュー可能で再現性のある基準で判定する。

### Strategy

まず文書化された評価セットで品質期待値を固定し、次にfixture化、自動採点、CI gateへ段階的に進める。

### Tactics

- 対象出力項目をOpenAPI上のRequirement項目に合わせる
- 矛盾、機微情報、情報不足を含むサンプルケースを定義する
- 100点rubric、合格基準、Critical failureを定義する
- 失敗パターンごとの改善アクションを用意する

### Assessment

評価の軸は妥当で、世界レベルSaaS基準に必要な安全性、監査性、レビュー容易性を含んでいる。一方、現時点では文書品質に留まり、実生成結果の劣化を自動検知する力はまだない。

### Conclusion

条件付き合格。Issue #3のP0「Requirement生成品質評価セット」は文書としては完了。ただし、プロダクト品質保証としてはfixture化と初回採点が完了するまで未成熟である。

### Knowledge

AI生成品質はpromptの良し悪しだけでなく、評価データ、採点基準、失敗時の改善ループ、レビューgateまで含めて初めて統制できる。

## ISO25010

| 品質特性 | 評価 | 改善 |
| --- | --- | --- |
| 機能適合性 | Requirement出力項目、rubric、合格基準は目的に合う | 実生成結果を採点し、baselineを取る |
| 信頼性 | Critical failureを定義し重大事故を防ぐ設計がある | 自動回帰評価がないため、CIで劣化検知する |
| 使用性 | レビュアーが何を見るべきか分かりやすい | 採点シートと例示採点を追加する |
| 保守性 | 失敗パターンと改善アクションが分かれている | rubric versioningと更新履歴を追加する |
| セキュリティ | PII、secret、レビューgateを評価に含めている | secret scan結果との機械的連携が必要 |
| 互換性 | OpenAPI Requirement schemaと概ね対応している | 根拠追跡性やconfidenceの保存先を再設計する |

## MoSCoW

| 区分 | 内容 | 状態 |
| --- | --- | --- |
| Must | 評価目的、対象項目、サンプル、rubric、合格基準、失敗時アクション、自動化案を文書化する | 完了 |
| Must | 評価セットを実行可能fixtureにする | 未完了 |
| Must | 現行providerのbaseline scoreを保存する | 未完了 |
| Should | LLM judgeと人間レビューを比較する | 未完了 |
| Could | 評価scoreをReview Centerで可視化する | 未完了 |
| Won't now | 評価スコアだけでRequirementを完全自動承認する | 非スコープ |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | 生成元追跡を評価対象に含めた | provider/model/prompt version保存を設計する |
| Tampering | Requirement修正差分の評価観点はある | artifact versioningと差分監査が必要 |
| Repudiation | scorecard保存案はあるが未実装 | 評価実行者、時刻、入力hashを保存する |
| Information Disclosure | secret/PII再掲をCritical failureにした | secret scanとの連携を自動化する |
| Denial of Service | 自動評価コストの扱いは未定 | CIでは初期warning運用にする |
| Elevation of Privilege | レビューgate未完了時の次工程停止を評価する | 承認APIと権限設計で強制する |

## 判定

条件付き合格。文書としてのRequirement生成品質評価セットはIssue #3のP0未完了を解消した。ただし、実行可能評価とbaseline取得がないため、Issue #3全体は完了扱いにしない。
