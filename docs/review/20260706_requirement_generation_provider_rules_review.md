# 2026-07-06 Requirement生成provider改善レビュー

## 評価日時

2026-07-06 20:10:00 JST

## 評価担当

Codex as AI Architect / Tech Lead / Backend Architect / Security Engineer / QA

## Issue番号

GitHub Issue #3

## 対象成果物

- `backend/app/services/requirement_generation/deterministic_provider.rb`
- `backend/spec/services/requirement_generation_deterministic_provider_spec.rb`
- `docs/evaluation/20260706_requirement_generation_provider_rules_baseline.md`
- `docs/evaluation/20260706_requirement_generation_baseline.md`

## 使用フレームワーク

- G-STACK
- ISO25010
- STRIDE
- MoSCoW
- QA回帰テスト

## 評価サマリー

初回baselineで検出されたP0未達6件に対して、deterministic providerへ非スコープ抽出と非機能要件抽出のruleを追加した。改善後baselineは平均100.0 / 100、P0未達0件、Critical failure 0件となり、現行fixture上は合格した。

同時に、providerインスタンス再利用時に前回Minutesの `source_text` が残る不具合を検出し、生成ごとにキャッシュをリセットする修正を入れた。これは評価精度だけでなく実運用上の文脈混入リスクにも関わるため、今回の重要な改善である。

## G-STACK評価

### Goal

Requirement draftが、非スコープ、セキュリティ、監査、CI、UXを落とさず次工程のレビューに渡せる状態にする。

### Strategy

LLM推論に依存しないdeterministic providerで、明示的に会議内に出た制約語を拾い、`out_of_scope` と `non_functional_requirements` へ分類する。

### Tactics

- SSO、Backend/Frontend実装、未設定項目、自動採点ブロックを非スコープとして抽出
- PII、secret、マスキング、権限境界、監査ログを非機能要件として抽出
- CI警告、差分確認、UX、OpenAPI乖離監査を非機能要件として抽出
- provider再利用時のsource textキャッシュを生成ごとにリセット
- provider単体RSpecを追加

### Assessment

改善後baselineは合格。初回baselineで弱かったP0観点は全ケースで配点80%以上を満たした。

### Conclusion

deterministic providerのfixture上の品質改善は完了。次はOpenAI provider比較、approved RequirementとIssue/OpenAPI生成条件の接続、Review Centerとの承認状態連携へ進める。

### Knowledge

AI PMのRequirement生成では、本文生成よりも「やらないこと」「扱ってはいけない情報」「次工程へ渡してはいけない条件」を抽出できるかが信頼性を左右する。

## 良かった点

- 初回baselineで弱点を定量化してから改善に入ったため、対応範囲が明確だった。
- PII、secret、権限、監査、CI、UXを会議文脈から抽出できるようになった。
- 非スコープを固定文だけにせず、Minutes内の制約語から拡張できるようになった。
- provider再利用時のキャッシュ混入を検出し、回帰テストで固定した。
- 評価レポートを初回と改善後で分けたため、改善効果を追跡できる。

## 改善点

- 期待語ベースの評価で100点になっているため、実際の多様な表現に対する堅牢性はまだ過信できない。
- ruleが増え始めており、今後は小さな分類器またはpolicy objectへ切り出す余地がある。
- OpenAI providerは未実装のため、実AI出力との比較評価はまだできていない。
- `out_of_scope` と `non_functional_requirements` の根拠発言IDはまだ保持していない。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | approved RequirementをIssue/OpenAPI生成条件へ接続 | API駆動開発の次工程gateに直結する |
| P0 | Review Centerのresolved状態とRequirement承認条件を接続 | 未決事項を残したまま次工程へ進む事故を防ぐ |
| P1 | OpenAI providerを同fixtureで比較 | 実AI導入時の品質差分を測れるようにする |
| P1 | 根拠発言IDとconfidenceをRequirement項目へ付与 | レビュー容易性と監査性を上げる |
| P2 | ruleをpolicy objectへ整理 | provider肥大化を抑える |

## 次アクション

- Issue #3では、approved RequirementとIssue/OpenAPI生成条件の接続へ進む。
- Review Centerのresolved状態をRequirement承認条件へ接続する。
- OpenAI provider導入時は、今回のfixtureとbaseline scriptを必ず再利用する。

## 判定

合格。

deterministic providerのP0品質改善は完了。ただしIssue #3全体は、次工程接続と承認状態連携が残るため継続する。
