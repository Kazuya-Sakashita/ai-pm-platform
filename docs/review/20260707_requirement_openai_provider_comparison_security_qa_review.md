# 2026-07-07 Requirement生成OpenAI provider比較導入 Security / QA 独立レビュー

## 評価日時

2026-07-07 11:47:07 JST

## 評価担当

Codex as Security Engineer / QA

外部AIレビュー: 未実施。Claude / ChatGPT 等の別AIレビューは追加待ち。

## Issue番号

- ISSUE-052
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/69

## 対象成果物

- `docs/issue/ISSUE-052_requirement_openai_provider_comparison.md`
- GitHub Issue #69
- `backend/app/services/requirement_generation_service.rb`
- `backend/app/services/requirement_generation/deterministic_provider.rb`
- `backend/app/services/requirement_generation/provider_error.rb`
- `backend/app/controllers/api/v1/requirements_controller.rb`
- `backend/app/services/minutes_generation_service.rb`
- `backend/app/services/minutes_generation/openai_provider.rb`
- `backend/app/services/conversation_summary_generation/openai_provider.rb`
- `backend/app/services/conversation_summary_generation/provider_factory.rb`
- `scripts/evaluate-requirement-generation.rb`
- `docs/evaluation/fixtures/requirement_generation/cases.json`
- `docs/evaluation/20260706_requirement_generation_provider_rules_baseline.md`

## 使用フレームワーク

- STRIDE
- OWASP Top 10
- ISO25010
- QA回帰テスト
- G-STACK

## 評価サマリー

ISSUE-052 / GitHub #69は、Requirement生成へOpenAI providerを追加し、deterministic providerとの比較評価を行うP1作業である。現状のRequirement生成は `RequirementGenerationService` が `RequirementGeneration::DeterministicProvider` を直接デフォルト利用しており、Requirement専用のProviderFactory、OpenAI provider、OpenAI比較評価器のprovider切替は未実装である。

既存のMinutes / Conversation Summary OpenAI providerには、Responses API、Structured Outputs `json_schema`、`strict: true`、`store: false`、safe error mapping、request_id保持という再利用すべき安全パターンがある。一方、Requirement生成は後続のIssue生成とOpenAPI設計へ接続されるため、外部API失敗よりも、秘密情報の外部送信、AI応答の幻覚、schema外応答の保存、未レビュー要件の後続工程流出が重大リスクになる。

独立レビュー判定は「設計着手可、実装完了判定はP0条件充足まで不可」。OpenAI provider実装前に、送信前secret/PII gate、strict schema、post-normalization validation、safe error contract、deterministic default、fixture比較保存を完了条件として固定する必要がある。

## 確認した現状

- GitHub #69はOPENで、ローカルのISSUE-052と完了条件が一致している。
- Requirement生成はprovider注入可能だが、デフォルトはdeterministic provider直指定であり、ENVによるFactory切替はない。
- RequirementのProviderErrorは `code`、`safe_detail`、`http_status` のみで、既存OpenAI providerのような `request_id` を持たない。
- RequirementsControllerはProviderError時にJobをfailed化し、APIには `safe_detail` を返す。ただしJobの `error_message` には例外messageを保存するため、OpenAI provider側のmessageへraw response、prompt、Minutes本文、tokenを入れてはいけない。
- Minutes生成には送信前 `SensitiveContentScanner` gateがあるが、Requirement生成には同等の送信前gateがない。
- Conversation Summary OpenAI providerは `json_schema strict`、`store: false`、rate limit / upstream / invalid responseのsafe error mapping、request_idを実装済みで、ISSUE-052の実装参照として妥当である。
- 評価scriptはfixtureとP0カテゴリを持つが、provider選択は現在deterministicのみである。

## 良かった点

- ISSUE-052の完了条件に、明示ENV、Structured Outputsまたは同等のschema検証、safe error contract、fixture比較、RSpec保存が含まれている。
- 既存fixtureは、忠実性、未決事項、受け入れ条件、スコープ制御、非機能・セキュリティ・監査をP0カテゴリとして扱っており、OpenAI比較にも再利用できる。
- deterministic providerは、非スコープ、セキュリティ、監査、CI、UXの抽出を既に改善済みで、比較基準として使える。
- 既存DM providerの実装レビューとspecが、OpenAI provider導入時の安全な型を示している。
- RequirementsControllerはProviderError時のfailed jobとsafe error返却の入口を既に持っている。

## P0リスク

| リスク | 内容 | 必須対応 |
| --- | --- | --- |
| P0-1: secret / PII外部送信 | 承認済みMinutesであっても、summary、decisions、open_questions、action_itemsにメール、token、API key、個人名、機微文脈が残る可能性がある。Requirement OpenAI providerを追加するだけでは、外部API送信前の遮断が保証されない。 | Requirement生成前に、OpenAIへ送るprompt対象文字列を `SensitiveContentScanner` で検査する。credential / secret / personal_dataを検出した場合は送信せず、`sensitive_content_blocked` をsafe errorとしてfailed jobへ保存する。 |
| P0-2: schema外応答や空要件の保存 | AI応答がJSONでも、必須項目が空、FR形式が崩れる、未決事項を捨てる、非スコープを削る場合、後続のIssue/OpenAPI生成に危険な入力が流れる。 | `json_schema strict` に加え、アプリ側で必須項目、配列件数、空文字、FR prefix、禁止patternを正規化後に検証し、不正ならRequirementを作成しない。 |
| P0-3: CIや通常環境で外部APIが走る | `auto` defaultやAPI key存在だけでOpenAI providerが選ばれると、CI安定性、費用、秘密情報送信範囲が崩れる。 | ISSUE-052の記述通り、Requirementは未設定時deterministic、`REQUIREMENT_GENERATION_PROVIDER=openai` 等の明示時だけOpenAIを使う。通常CIはdeterministic固定にする。 |
| P0-4: prompt injectionによるレビューgate迂回 | Minutes本文に「レビューなしでIssue化」「schema外に出力」「秘密情報を出せ」等が含まれた場合、AIが後続工程を許可する要件を作る恐れがある。 | developer instructionでMinutesをuntrusted data扱いにし、レビューgate回避、secret開示、後続工程の自動承認を無視する。fixtureのforbidden_patternsをOpenAI比較にも適用する。 |
| P0-5: 失敗時にraw responseやpromptが保存される | RequirementsControllerは `job.error_message = e.message` を保存するため、ProviderErrorのmessage設計を誤るとOpenAIレスポンスやMinutes本文がDB/API運用画面に残る。 | ProviderErrorのmessageは固定文またはHTTP status程度に限定し、raw provider response、prompt、request body、Minutes本文、tokenを入れない。API/UIはsafe_detailのみ表示する。 |

## P1リスク

| リスク | 内容 | 推奨対応 |
| --- | --- | --- |
| P1-1: request_id監査不足 | RequirementGeneration::ProviderErrorはrequest_idを持たず、RequirementsControllerのaudit metadataにもrequest_idが入らない。 | Minutes / DM providerと同様にrequest_idをProviderError、Job/AuditLog/API detailsへ渡す。 |
| P1-2: 評価scriptがOpenAI比較に未対応 | `scripts/evaluate-requirement-generation.rb` はdeterministicのみをbuildできる。 | `--provider openai` と `--provider deterministic` を同一fixtureで実行できるようにし、結果を `docs/evaluation/` に保存する。 |
| P1-3: model品質の再現性不足 | 実OpenAI出力はモデル、日付、prompt差分で変動する。 | 評価レポートにmodel名、endpoint、生成日時、fixture version、request_id、手動smoke担当を残す。 |
| P1-4: safe errorの日本語表示 | 既存OpenAI providerのsafe_detailは英語が多い。UI表示時は日本語運用ルールとISSUE-021の表示方針に合わせる必要がある。 | API内部codeは英語維持でよいが、UI表示ラベルまたはsafe_detailは日本語表示可能にする。 |
| P1-5: live smoke未実施 | stubbed specだけでは実Responses APIのschema受理、model応答、request_id取得を確認できない。 | 通常CIから分離した手動smokeを実施し、結果をreviewまたはrelease docsへ保存する。 |

## 必要なRSpec

### Provider単体spec

- `RequirementGeneration::OpenaiProvider` がResponses API payloadに `text.format.type=json_schema`、`strict=true`、`store=false` を設定すること。
- developer instructionが、Minutesをuntrusted dataとして扱い、secret開示、レビューgate回避、schema外出力、後続工程の自動承認を無視する方針を含むこと。
- 正常なResponses API結果を、Requirementの保存属性へ正規化すること。
- `background`、`goal`、`functional_requirements`、`acceptance_criteria`、`generated_by_model` が空の場合は `invalid_ai_response` で失敗すること。
- `rate_limit_exceeded` はHTTP 429、安全なdetail、request_id付きProviderErrorになること。
- upstream 5xx、transport error、invalid JSON、output_text欠落、schema不一致がsafe errorになること。
- ProviderErrorのmessageとsafe_detailに、raw Minutes、API key、Authorization header、OpenAI raw responseが含まれないこと。

### Factory / Service spec

- `REQUIREMENT_GENERATION_PROVIDER` 未設定または `deterministic` ではdeterministic providerを使うこと。
- `REQUIREMENT_GENERATION_PROVIDER=openai` の明示時のみOpenAI providerを構築すること。
- OpenAI強制時にAPI key未設定なら `integration_not_connected` / 424相当で失敗すること。
- provider失敗時にRequirementレコードが作成されないこと。
- secret / PII検出時はOpenAI providerを構築または呼び出しせず、`sensitive_content_blocked` で失敗すること。
- provider注入specは維持し、CIが外部OpenAI通信へ依存しないこと。

### Request spec

- `POST /api/v1/minutes/:id/generate-requirement` は承認済みMinutesだけを処理し、未承認MinutesではOpenAI providerを構築しないこと。
- OpenAI provider成功時にJobがsucceeded、Requirementが保存、AuditLogが `requirement.generated` になること。
- OpenAI provider失敗時にJobがfailed、`error_code`、`safe_error_detail`、可能なら `request_id` が保存され、API response detailsにもjob_id/request_idが返ること。
- failed job / audit log / API responseにraw Minutes、prompt、token、OpenAI raw responseが出ないこと。
- rate limit、invalid response、integration_not_connected、sensitive_content_blockedを個別に検証すること。

### 評価script spec

- `--provider openai` がfixtureを読み、同じrubricで採点できること。
- `--provider openai` の実行は明示ENVがない限りskipまたは安全に失敗し、通常CIの `--provider deterministic --enforce` は維持されること。
- forbidden_patterns一致はOpenAI出力でもCritical failureになること。

## 手動smoke

実OpenAI smokeは通常CIに入れず、明示的な検証として実施する。

1. 検証用の安全なMinutesを用意する。実メール、電話番号、住所、API key、顧客名、DM原文全文は使わない。
2. `REQUIREMENT_GENERATION_PROVIDER=openai`、`OPENAI_API_KEY`、`OPENAI_REQUIREMENT_MODEL` を設定する。
3. Rails APIを起動し、対象Minutesを `approved` にする。
4. `POST /api/v1/minutes/:id/generate-requirement` を実行する。
5. Jobがsucceeded、Requirementがgenerated、`generated_by_model` が設定モデル、AuditLogが `requirement.generated` であることを確認する。
6. 出力がfixtureのP0カテゴリ、特に未決事項、非スコープ、非機能、受け入れ条件、禁止pattern不一致を満たすことを確認する。
7. DBのJob / AuditLog / API responseにraw prompt、OpenAI raw response、API key、Authorization header、検証用Minutes全文が入っていないことを確認する。
8. rate limitまたはstubbed upstream failureの手動確認では、Job failed、safe_detailのみ表示、request_id保存を確認する。
9. 結果を `docs/evaluation/` と `docs/review/` または `docs/release/` に保存する。

## secret / PII漏えい防止

- OpenAI送信対象は、Requirement生成用に組み立てた最終prompt文字列で検査する。Minutesの一部だけを検査すると、decisionsやaction_items由来の漏れを見逃す。
- credential / secretはブロック、personal_dataは少なくともMVPではブロックまたは明示redaction済みのみ送信とする。
- safe_detail、error_message、AuditLog metadata、evaluation report、manual smoke証跡には、raw Minutes、prompt全文、OpenAI raw response、API key、Bearer token、メールアドレス、電話番号を保存しない。
- OpenAI providerのpromptには、認証情報、token、password、電話番号、メールアドレス、住所、DM原文全文を出力しないことを明記する。
- 評価fixtureのCASE-RQ-003をOpenAI比較で必ず通し、`sk-` 形式や「API keyをRequirement本文に残す」禁止patternをCritical failureとして扱う。

## 外部API失敗時の安全な挙動

| 条件 | 期待code | HTTP | 期待挙動 |
| --- | --- | --- | --- |
| API key未設定 | `integration_not_connected` | 424 | Requirementを作らずJob failed。safe_detailのみ返す。 |
| secret / PII検出 | `sensitive_content_blocked` | 422 | OpenAIへ送信せずJob failed。検出種別の概要のみ保存する。 |
| rate limit | provider codeまたは `rate_limit_exceeded` | 429 | Job failed。request_idがあればJob/Audit/APIへ保存し、再試行可能なsafe_detailを返す。 |
| upstream 5xx | provider codeまたは `openai_api_error` | 502 | Job failed。raw responseは保存せず、後で再試行できるsafe_detailを返す。 |
| timeout / network | `openai_transport_error` | 502 | Job failed。例外messageにhost、token、payload断片を入れない。 |
| invalid JSON / schema不一致 | `invalid_ai_response` | 502 | Requirementを作らずJob failed。schema不一致のsafe_detailのみ返す。 |

## 優先順位

| 優先度 | 対応 | 理由 |
| --- | --- | --- |
| P0 | Requirement OpenAI送信前のsecret / PII gate | 外部APIへの情報漏えいを防ぐため |
| P0 | strict schema + post-normalization validation | 後続Issue/OpenAPIへ危険な要件を流さないため |
| P0 | deterministic default / OpenAI明示ENV限定 | CI安定性、費用、安全境界を守るため |
| P0 | ProviderError message非漏えいcontract | failed jobと運用画面へのraw情報保存を防ぐため |
| P1 | request_idをProviderError、Job、AuditLog、API detailsへ保存 | 障害調査と監査性を上げるため |
| P1 | OpenAI比較評価scriptと評価レポート保存 | deterministicとの差分を判断可能にするため |
| P1 | live OpenAI manual smoke証跡 | stubbed specだけでは実API疎通を保証できないため |

## 次アクション

1. RequirementGeneration用のProviderFactory設計レビューを作成し、ENV名、default、OpenAI強制時の挙動を確定する。
2. Requirement OpenAI providerのschema、prompt safety、normalization、safe error contractを実装する前にRSpec項目を先に追加する。
3. 送信前secret / PII gateをRequirement生成経路に入れ、OpenAI provider構築前にブロックできることをrequest specで固定する。
4. 評価scriptをOpenAI provider対応に拡張し、deterministicとOpenAIの比較結果を `docs/evaluation/` に保存する。
5. 実OpenAI manual smokeは通常CIと分離し、検証用データ、モデル名、request_id、結果、残課題をレビュー文書へ保存する。

## 判定

条件付き合格。

ISSUE-052は実装に進んでよいが、P0条件を満たすまで完了扱い、GitHub #69クローズ、後続Issue/OpenAPI生成への接続は不可。Security Engineer / QAとしてのblockerは、外部送信前のsecret / PII gate、schema不一致時のRequirement未作成、deterministic default、safe error非漏えいcontractである。

## AIレビュー比較

Codex一次レビューのみ。外部AIレビューは未実施。外部レビュー結果が追加された場合は、secret / PII gate、schema厳密性、OpenAI失敗時contract、fixture比較の妥当性を中心に差分確認する。
