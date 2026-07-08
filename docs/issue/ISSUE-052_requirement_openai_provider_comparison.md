# ISSUE-052: Requirement生成OpenAI providerを比較評価付きで導入する

## Issue番号

ISSUE-052

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/69

登録日: 2026-07-07
状態: OPEN

## 背景

Requirement生成はdeterministic providerと品質fixtureが整備済みだが、OpenAI providerによる実AI生成とdeterministic providerの比較評価が未実施である。

## 目的

Requirement生成のOpenAI providerを明示設定時のみ利用できるようにし、既存fixtureでdeterministic providerと比較して品質と安全性を判断できるようにする。

## 完了条件

- RequirementGenerationのOpenAI providerが実装される
- 通常CIはdeterministic providerのまま安定する
- OpenAI providerは明示ENV時のみ利用される
- Structured Outputsまたは同等のJSON schema検証がある
- provider失敗時のsafe error contractがある
- 既存fixtureでdeterministic providerとの比較結果を `docs/evaluation/` へ保存する
- 設計レビュー、実装レビュー、RSpecを保存する

## スコープ

- Requirement OpenAI provider
- ProviderFactoryまたは同等の切替
- 評価fixture再利用
- 安全な失敗処理
- 手動smoke手順

## 非スコープ

- 本番常時OpenAI利用への切替
- Prompt最適化の長期実験
- 外部AIレビュー自動実行基盤

## 関連レビュー

- `docs/review/20260630_requirements_generation_mvp_review.md`
- `docs/review/20260706_requirement_generation_quality_baseline_review.md`
- `docs/review/20260706_requirement_generation_provider_rules_review.md`
- `docs/review/20260707_requirement_followup_issue_split_review.md`
- `docs/review/20260707_requirement_openai_provider_design_review.md`
- `docs/review/20260707_requirement_openai_provider_comparison_security_qa_review.md`
- `docs/review/20260707_requirement_openai_provider_implementation_review.md`
- `docs/review/20260708_requirement_openai_schema_hardening_review.md`
- `docs/review/20260708_requirement_openai_live_readiness_review.md`

## レビュー結果

Requirement生成品質の上限を引き上げるP1作業である。ただし、外部API依存をCIへ持ち込むと品質ゲートが不安定化するため、明示ENV、fixture比較、safe failureを前提にする。

2026-07-07更新: OpenAI provider、ProviderFactory、safe error、request id監査、secret/PII送信前block、評価scriptのOpenAI provider指定、RSpecを追加した。deterministic baselineは合格。実OpenAI APIを使ったlive fixture評価は未実施のため、Issue完全クローズ前にmanual smokeまたは明示的なリスク受容が必要。

2026-07-07追記: PR #77 の GitHub Actions `verify` は成功。backend specs、autoloading、OpenAPI、JWT keyring、表示ラベル、frontend build、frontend E2Eが通過した。

2026-07-08追記: OpenAI live manual smoke実施前に、`functional_requirements` のStructured Outputs schemaへ `^FR-\d{3}:\s+.+` patternを追加した。Ruby側のpost-normalization validationは維持し、schemaとアプリ側validationの二重防御にした。対象RSpecは39 examples, 0 failures、deterministic fixture評価は平均100.0 / 100、P0未達0件、Critical failure 0件で合格した。OpenAI API keyはこの環境では未設定のため、live fixture評価は未実施である。secret値は表示、保存していない。

2026-07-08追記: OpenAI live評価へ進む前段として、secret値を出力しない `scripts/requirement-openai-live-readiness.rb` と `npm run requirements:openai:readiness` を追加した。現在の環境では `OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` が未設定であり、safe failureは `openai_api_key_missing`、`openai_requirement_model_missing` だった。fixtureと出力先は確認済みで、設定後に `evaluate-requirement-generation.rb --provider openai --enforce` を実行できる。API key値、raw response、model outputは保存していない。

## 優先度

P1

## 次アクション

1. schema hardeningの対象RSpecとdeterministic fixture評価を確認する。
2. `npm run requirements:openai:readiness` を再実行し、`safe_failures` が空であることを確認する。
3. 安全な検証環境で `OPENAI_API_KEY` と `OPENAI_REQUIREMENT_MODEL` を設定し、OpenAI live manual smokeを実施する。
4. smoke結果を `docs/evaluation/` と `docs/review/` へ追記する。
5. live結果がP0基準を満たす、または残リスクを明示受容した場合にGitHub Issue #69をクローズする。
