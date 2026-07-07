# 2026-07-07 Requirement生成OpenAI provider設計レビュー

## 評価日時

2026-07-07 11:40:00 JST

## 評価担当

Codex as AI Architect / Backend Architect / Tech Lead / Security Engineer / QA

## Issue番号

GitHub Issue #69 / ISSUE-052

## 対象成果物

- `docs/issue/ISSUE-052_requirement_openai_provider_comparison.md`
- `backend/app/services/requirement_generation_service.rb`
- `backend/app/services/requirement_generation/deterministic_provider.rb`
- `scripts/evaluate-requirement-generation.rb`

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- MoSCoW
- QA回帰テスト

## 評価サマリー

Requirement生成へOpenAI providerを追加する価値は高い。ただし、RequirementはIssue生成、OpenAPI設計、実装工程へ直接つながるため、実AIの導入は「明示設定時のみ」「Structured Outputsでschema制約」「失敗時はsafe error」「通常CIはdeterministic維持」をP0条件にする。

既存のMinutes生成、DM整理providerはResponses APIとschema検証の実装パターンを持っているため、Requirement側も同じ安全契約へ揃える。ただし、Requirementは未決事項、非スコープ、非機能要件の抜けがプロジェクト事故につながるため、単に文章を上手にするのではなく、評価fixtureでdeterministic providerとの差分を残せる設計にする。

## G-STACK評価

### Goal

Requirement生成でOpenAI providerを選択可能にし、AI PMとしてより自然で網羅的な要件ドラフトを作れるようにする。

### Strategy

通常運用とCIはdeterministic providerを維持し、OpenAI providerは `REQUIREMENT_GENERATION_PROVIDER=openai` または明示的な `auto` 指定時だけ有効化する。未設定時にAPI keyの存在だけでOpenAIへ切り替えない。外部API依存を通常テストへ持ち込まず、provider単体RSpecと評価scriptの手動実行で比較可能にする。

### Tactics

- `RequirementGeneration::ProviderFactory` を追加し、Serviceからprovider選択責務を分離する。
- `RequirementGeneration::OpenaiProvider` を追加し、Responses APIのStructured Outputs相当のJSON schemaを要求する。
- OpenAI失敗、rate limit、invalid schema、API key未設定をsafe errorへ変換する。
- `ProviderError` にrequest idを持たせ、監査ログとAPI error detailsへ安全に引き継ぐ。
- 評価scriptで `--provider openai` を指定可能にし、deterministic baselineとOpenAI manual smokeの比較結果を保存できるようにする。

### Assessment

設計は既存アーキテクチャへ自然に接続できる。最大リスクはOpenAI出力がfixture採点を満たさない、または実API未設定で比較が未完了のまま完了扱いになること。よって、初回実装ではOpenAI providerのcontractをRSpecで固め、live評価はAPI keyがある環境の手動smokeとして明示的に残す。

### Conclusion

実装へ進んでよい。ただし、Issue #69を完了扱いにする条件は、少なくともdeterministic baseline、OpenAI provider contract test、手動OpenAI評価手順または未実施理由が `docs/evaluation/` に残ることである。

### Knowledge

AI PMにおけるRequirement生成は、流暢さよりも「レビュー可能な構造」「未決事項の保持」「非スコープの明示」「監査可能な失敗」が重要である。

## 良かった点

- 既存のMinutes生成、DM整理providerに安全なResponses API実装パターンがある。
- Requirement deterministic providerと品質fixtureがすでにあり、比較評価の土台がある。
- Issue #69で明示ENV、safe failure、CI deterministic維持が完了条件に入っている。
- 通常ServiceはRequirement保存責務に集中でき、provider切替はFactoryへ分離できる。

## 改善点

- OpenAI providerは未実装で、Requirement schemaの妥当性がまだ検証されていない。
- live OpenAI比較はAPI keyとネットワークに依存するため、ローカルCIだけでは完了判定ができない。
- 評価fixtureは期待語ベースのため、OpenAIの自然な言い換えを過小評価する可能性がある。
- provider失敗時のrequest idがRequirement側のProviderErrorにはまだ存在しない。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | OpenAI providerを明示ENVのみで有効化 | CIと通常開発を外部API依存にしない |
| P0 | JSON schema検証とsafe error contract | 不正AI応答と外部API失敗を監査可能にする |
| P0 | request idを監査ログとAPI detailsへ残す | 障害調査で外部provider応答を追跡しやすくする |
| P1 | 評価scriptでOpenAI providerを指定可能にする | deterministicとの差分比較を再現可能にする |
| P1 | live OpenAI smoke未実施時の未完了理由を保存 | 実API検証を曖昧に完了扱いしない |

## 次アクション

1. `RequirementGeneration::ProviderFactory` を追加する。
2. `RequirementGeneration::OpenaiProvider` を追加する。
3. `RequirementGenerationService` はprovider注入とFactory選択だけを扱う。
4. `ProviderError` とControllerの監査メタデータへrequest idを追加する。
5. RSpecと評価scriptを更新し、比較結果を `docs/evaluation/` へ保存する。

## 判定

条件付き合格。

OpenAI provider実装へ進んでよい。ただし、live OpenAI比較を実行できない場合は、その理由と手動smoke手順を明記し、Issue完了判定では残リスクとして扱う。
