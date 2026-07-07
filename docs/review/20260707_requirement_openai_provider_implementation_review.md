# 2026-07-07 Requirement生成OpenAI provider実装レビュー

## 評価日時

2026-07-07 11:53:20 JST

## 評価担当

Codex as AI Architect / Backend Architect / Tech Lead / Security Engineer / QA

外部AIレビュー: 未実施。Claude / ChatGPT等の外部AIレビューは追加待ち。

## Issue番号

GitHub Issue #69 / ISSUE-052

## 対象成果物

- `backend/app/services/requirement_generation/openai_provider.rb`
- `backend/app/services/requirement_generation/provider_factory.rb`
- `backend/app/services/requirement_generation/provider_error.rb`
- `backend/app/services/requirement_generation_service.rb`
- `backend/app/controllers/api/v1/requirements_controller.rb`
- `scripts/evaluate-requirement-generation.rb`
- `frontend/lib/display-labels.ts`
- `backend/spec/services/requirement_generation/openai_provider_spec.rb`
- `backend/spec/services/requirement_generation/provider_factory_spec.rb`
- `backend/spec/services/requirement_generation_service_spec.rb`
- `backend/spec/requests/api/v1/requirements_spec.rb`
- `backend/spec/scripts/evaluate_requirement_generation_spec.rb`
- `docs/evaluation/20260707_requirement_generation_openai_provider_comparison.md`

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- QA回帰テスト

## 評価サマリー

ISSUE-052の主要実装として、Requirement生成にOpenAI providerを追加し、`REQUIREMENT_GENERATION_PROVIDER=openai` または明示的な `auto` 指定時だけ利用できるようにした。未設定時はdeterministic providerのまま動作するため、CIとローカル開発は外部APIに依存しない。

OpenAI providerはResponses APIのStructured Outputs形式に合わせ、`json_schema`、`strict: true`、`store: false` を送信する。応答はアプリ側でも必須項目、空配列、FR prefix、禁止patternを検証し、invalid JSON、schema不一致、output欠落、rate limit、upstream error、API key未設定をsafe errorへ変換する。request idはProviderError、AuditLog、API error detailsへ連携した。

Security/QA観点では、外部送信前のsecret/PII gateをRequirement生成Serviceへ追加し、provider構築前にブロックするようにした。これにより、OpenAI providerが選択されていても、ブロック対象のMinutes由来テキストは外部送信されない。

## G-STACK評価

### Goal

Requirement生成の品質上限をOpenAI providerで引き上げつつ、通常CIと安全境界を壊さない。

### Strategy

deterministic defaultを維持し、OpenAIは明示ENVだけで有効化する。`auto` も未設定defaultではなく明示指定として扱う。外部API連携はProviderに閉じ、Serviceはsecret/PII gateとRequirement保存、Controllerは監査とsafe error返却に限定する。

### Tactics

- `RequirementGeneration::ProviderFactory` でprovider選択を分離
- `RequirementGeneration::OpenaiProvider` でResponses API payload、schema、normalization、safe errorを実装
- `RequirementGeneration::ProviderError` にrequest idを追加
- Requirement生成Serviceで送信対象テキストを `SensitiveContentScanner` に通す
- 評価scriptで `--provider openai` を指定可能にする
- RSpecでOpenAI成功、invalid response、rate limit、upstream error、API key未設定、secret block、request id監査を確認

### Assessment

contract実装は合格。対象RSpec 39件、backend全体RSpec、Zeitwerk、frontend build、表示ラベルチェック、deterministic fixture評価は通過した。一方、実OpenAI APIを使ったlive fixture評価は未実施であり、OpenAI出力が既存rubricでP0基準を満たすかは未確定である。

### Conclusion

PR作成へ進んでよい。ただし、GitHub Issue #69の完全クローズは、live OpenAI manual smokeまたは明示的なリスク受容を待つのが妥当である。

### Knowledge

AI PMの外部AI連携では、providerを追加すること自体よりも、外部送信前のブロック、schema外応答の未保存、監査可能なrequest id、通常CI非依存を維持することが品質の芯になる。

## 良かった点

- OpenAI providerが明示ENV時のみ有効で、未設定時と通常CIはdeterministicのまま維持できる。
- Structured Outputs形式のpayloadとアプリ側validationを併用している。
- secret/PII gateをprovider構築前に置いたため、OpenAI provider選択時も安全に失敗できる。
- ProviderErrorにrequest idを追加し、RequirementsControllerのAuditLogとAPI detailsへ引き継いだ。
- 評価scriptがOpenAI providerをbuildできるようになり、manual smokeの再現性が上がった。
- フロント表示ラベルへRequirement OpenAI failure系の日本語表示を追加した。

## 改善点

- 実OpenAI APIを使ったfixture採点は未実施で、model品質とprompt品質はまだ確定していない。
- Requirement生成前のsecret/PII gateは共通blockであり、将来はredaction済み入力だけを許可する運用判断が必要。
- OpenAI出力のFR prefixはpost-normalizationで拒否できるが、JSON schema patternではまだ強制していない。
- fixture評価は期待語一致に寄るため、OpenAIの自然な言い換えを過小評価する可能性がある。
- 外部AIレビュー比較は未実施で、Codex一次レビューに留まる。

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | live OpenAI manual smokeまたはリスク受容を保存 | OpenAI出力品質が未確定のため |
| P1 | FR prefixのJSON schema pattern化を検討 | provider段階でもIssue/OpenAPI readinessをさらに安定させるため |
| P1 | fixture採点に意味的類似評価を追加 | OpenAIの言い換えを適切に評価するため |
| P1 | 外部AIレビュー結果を比較追記 | AGENTSの複数AIレビュー方針へ近づけるため |
| P2 | provider別prompt versionを保存 | 将来の品質回帰調査を容易にするため |

## 次アクション

1. PRを作成し、CIで通常deterministic経路が壊れていないことを確認する。
2. `OPENAI_API_KEY` を安全に扱える環境でmanual smokeを実施する。
3. smoke結果を `docs/evaluation/` と `docs/review/` へ追記する。
4. live結果がP0基準を満たす、または残リスクを明示受容した場合にGitHub Issue #69をクローズする。

## 検証結果

- `bundle exec rspec spec/services/requirement_generation/openai_provider_spec.rb spec/services/requirement_generation/provider_factory_spec.rb spec/services/requirement_generation_service_spec.rb spec/requests/api/v1/requirements_spec.rb spec/scripts/evaluate_requirement_generation_spec.rb`: 39 examples, 0 failures
- `bundle exec rspec`: 326 examples, 0 failures
- `bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run display:check`: Display labels OK
- `npm run frontend:build`: 成功
- `bundle exec ruby ../scripts/evaluate-requirement-generation.rb --provider deterministic --output docs/evaluation/20260707_requirement_generation_openai_provider_comparison.md --quiet`: 合格、平均100.0 / 100、P0未達0件、Critical failure 0件
- GitHub Actions `verify`: 成功。Run `28838213484`、2m25s。backend specs、autoloading、OpenAPI、JWT keyring、表示ラベル、frontend build、frontend E2Eが通過。

## 参照

- OpenAI Structured Outputs: https://developers.openai.com/api/docs/guides/structured-outputs
- OpenAI Responses API create: https://developers.openai.com/api/reference/resources/responses/methods/create

## 判定

条件付き合格。

実装、contract test、deterministic baselineは合格。実OpenAI出力の品質はmanual smoke未実施のため、Issue #69の完全完了判定には追加証跡が必要である。
