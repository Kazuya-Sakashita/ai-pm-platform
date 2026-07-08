# 2026-07-08 Requirement生成OpenAI schema hardening review

## 評価日時

2026-07-08 11:46:52 JST

## 評価担当

Codex / AI Architect / Backend Architect / Security Engineer / QA

## Issue番号

ISSUE-052 / GitHub Issue #69

## 対象

- `backend/app/services/requirement_generation/openai_provider.rb`
- `backend/spec/services/requirement_generation/openai_provider_spec.rb`
- `docs/issue/ISSUE-052_requirement_openai_provider_comparison.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- QA回帰テスト

## 評価サマリー

OpenAI live manual smokeを実施する前に、既存レビューでP1改善として残っていたFR形式のschema hardeningを実施した。`functional_requirements.items.pattern` に `^FR-\d{3}:\s+.+` を追加し、Responses API Structured Outputsへ渡すJSON schema段階でも `FR-001: ...` 形式を要求する。

アプリ側のpost-normalization validationは維持する。schema制約はprovider入力境界を硬くするための一次防御であり、最終防御としてRuby側validationを残す。

OpenAI API keyはこの環境に設定されていなかったため、live fixture評価は未実施である。secret値は確認、保存、出力していない。

## 良かった点

- OpenAI providerのStructured Outputs schemaで、Issue/OpenAPIへ接続しやすいFR形式をより強制できるようになった。
- 既存のRuby側validationも残しており、model出力がschema外または後段品質基準外の場合にsafe errorへ落とせる。
- RSpecでResponses API payloadにpatternが含まれることを固定した。
- 通常CIはdeterministic provider defaultのままで、外部OpenAI APIに依存しない。
- live smoke未実施理由をAPI key未設定として明確にした。

## 改善点

- 実OpenAI APIでのlive fixture評価は未実施で、OpenAI出力品質はまだ未確定である。
- `pattern` があっても、要件内容の忠実性、未決事項、スコープ制御はfixture評価とレビューで確認する必要がある。
- `OPENAI_REQUIREMENT_MODEL` が未設定で、現状はprovider default modelに依存している。
- 外部AIレビュー比較は未実施で、Codex一次レビューに留まる。

## 改善案

1. 安全な検証環境で `OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` を設定し、fixture live評価を実施する。
2. live評価結果を `docs/evaluation/` に保存し、P0未達とCritical failureを確認する。
3. `docs/review/` へlive smokeレビューを保存し、Issue #69のクローズ可否を判断する。
4. OpenAI出力の言い換えを過小評価しないよう、将来は意味的類似評価を追加する。

## 優先順位

| 優先度 | 項目 | 理由 |
| --- | --- | --- |
| P0 | live fixture評価 | Issue #69の残る完了条件 |
| P1 | model明示設定 | provider default依存を避け、比較再現性を高める |
| P1 | 外部AIレビュー比較 | AGENTSの複数AIレビュー方針へ近づける |
| P2 | 意味的類似評価 | OpenAIの自然な言い換えを適切に評価する |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Requirement生成OpenAI providerの出力契約をlive評価前に強化する |
| Strategy | Structured Outputs schemaとRuby validationの二重防御にする |
| Tactics | `functional_requirements` のitemsへFR形式patternを追加し、RSpecでpayloadを固定 |
| Assessment | 契約は強化されたが、live出力品質はAPI key未設定のため未評価 |
| Conclusion | schema hardeningは採用。Issue #69はlive smokeまでOPEN |
| Knowledge | AI providerはschema制約だけでなく、後段rubricとsafe errorを残すことで運用品質が上がる |

## STRIDE / Security

- Spoofing: model出力を信頼しすぎず、schemaとアプリ側validationで検証する。
- Tampering: 議事録内のprompt injectionでFR形式を崩されにくくする。
- Repudiation: request id監査は既存実装を維持する。
- Information Disclosure: API key値、secret値、raw promptは保存していない。
- Denial of Service: live評価は通常CIへ入れず、外部API依存を分離する。
- Elevation of Privilege: レビューゲート回避文言は既存forbidden patternで拒否する。

## 検証結果

- OpenAI API key presence確認: 未設定。値は出力していない。
- `backend/spec/services/requirement_generation/openai_provider_spec.rb` にschema pattern確認を追加。
- `bundle exec rspec spec/services/requirement_generation/openai_provider_spec.rb spec/services/requirement_generation/provider_factory_spec.rb spec/services/requirement_generation_service_spec.rb spec/requests/api/v1/requirements_spec.rb spec/scripts/evaluate_requirement_generation_spec.rb`: 39 examples, 0 failures
- `bundle exec rspec`: 400 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `bundle exec ruby ../scripts/evaluate-requirement-generation.rb --provider deterministic --output docs/evaluation/20260708_requirement_generation_schema_hardening_deterministic.md --quiet`: 合格、平均100.0 / 100、P0未達0件、Critical failure 0件
- `npm run display:check`: Display labels OK

## 次アクション

1. 対象RSpecを実行する。
2. deterministic fixture評価を再実行し、通常経路が壊れていないことを確認する。
3. API keyが利用可能になったらOpenAI live fixture評価を実施する。
4. live結果がP0基準を満たす、または残リスクを明示受容した場合にIssue #69をクローズする。

## 参照

- OpenAI Structured Outputs: https://developers.openai.com/api/docs/guides/structured-outputs

## 結論

条件付き合格。OpenAI providerのschema contractは強化されたが、実OpenAI APIの品質比較は未実施である。世界レベルSaaS基準では、live fixture評価または明示的なリスク受容なしにIssue #69を完了扱いにしない。
