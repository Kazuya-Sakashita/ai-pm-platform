# 2026-06-30 Requirement生成品質評価セット

## メタデータ

- Issue番号: GitHub Issue #3
- 対象: 承認済みMinutesから生成されるRequirement draft
- 評価担当: Codex as AI Architect / Product Manager / QA / Security Engineer
- ステータス: v0.3 fixture化、採点自動化、deterministic provider改善後baseline取得済み。現行fixture上はP0未達0件。
- 前提: 生成結果は人間承認前提とし、レビューなしでIssue生成、OpenAPI設計、実装へ進めない。

## 評価目的

Requirement生成品質評価セットの目的は、議事録から生成された要件定義ドラフトが、Issue生成とOpenAPI設計の入力として使える品質に達しているかを一貫して判定することである。

世界レベルSaaS基準では、単に項目が埋まっているだけでは不十分である。会議内容への忠実性、曖昧さの抽出、受け入れ条件の検証可能性、セキュリティと監査観点、スコープ制御、レビュー容易性までを評価対象にする。

## 評価対象出力項目

| 項目 | 評価観点 | 不合格例 |
| --- | --- | --- |
| `background` | 会議で明示された課題、制約、背景が簡潔に反映されている | 会議にない市場規模、競合名、顧客名を作る |
| `goal` | 成果が測定可能で、次工程の判断に使える | 「使いやすくする」だけで成功条件がない |
| `user_stories` | actor、価値、理由が分かり、主要利用者を過不足なく表す | actorがすべて「ユーザー」で役割差が消える |
| `functional_requirements` | 動作、状態、入力、出力、例外が原子的に分かれている | 複数機能を1文に詰める、実装方式だけを書く |
| `non_functional_requirements` | セキュリティ、プライバシー、監査、性能、可用性、UXを必要に応じて含む | 機微情報を扱うのに権限、ログ、マスキングがない |
| `acceptance_criteria` | Given/When/Thenまたは同等の検証可能な条件になっている | 「正しく動く」「よい感じに表示する」 |
| `out_of_scope` | 会議で除外された内容、MVP外、後続Issueを明確にする | 非スコープが空で、過剰実装を止められない |
| `open_questions` | 曖昧な発言、未決定、矛盾、承認待ちを抽出する | 矛盾した意思決定を確定事項として扱う |
| `risks` | Product、Security、QA、Deliveryのリスクが具体的である | 一般論だけで、この要件固有のリスクがない |
| `generated_by_model` | provider、model、prompt versionの追跡に使える | 生成元が分からず、品質劣化時に追跡できない |
| レビュー補助情報 | 現行OpenAPI外でも、根拠発言、confidence、差分をレビューで確認できる | レビュアーが議事録へ戻らないと妥当性を判断できない |

## サンプルケース

### CASE-RQ-001: 標準的なMVP要件化

入力Minutes要約:

- CSチームはDiscord会議ログから議事録を作りたい。
- 議事録承認後に要件定義ドラフトを生成したい。
- MVPではGitHub Issue化は次フェーズでよい。
- 受け入れ条件は「承認済みMinutesのみ生成可能」「背景、目的、受け入れ条件、未決事項が保存される」。

期待される出力:

- `background`: 議事録後工程が属人化している課題を記述する。
- `goal`: 承認済みMinutesからIssue/OpenAPI前段のRequirement draftを作ることを記述する。
- `functional_requirements`: 生成、保存、編集、レビュー依頼を分ける。
- `acceptance_criteria`: approved Minutes以外は生成不可、必須項目保存、レビュー保存を検証可能にする。
- `out_of_scope`: GitHub Issue自動作成、完全自動承認を明記する。

失敗シグナル:

- GitHub Issue自動作成までMVPに含める。
- Minutes承認ゲートを省略する。
- 未決事項を空にする。

### CASE-RQ-002: 矛盾と未決事項の抽出

入力Minutes要約:

- Product Ownerは「Requirementは自動承認でよい」と発言した。
- Tech Leadは「レビューなしでIssue生成へ進めない」と発言した。
- Security Engineerは「外部AI出力は人間承認が必要」と発言した。
- 最終決定は保留になった。

期待される出力:

- `open_questions`: Requirement承認方法、承認者、ブロック条件を未決事項として抽出する。
- `risks`: 自動承認による誤要件、監査不能、セキュリティレビュー欠落を含める。
- `acceptance_criteria`: レビュー未完了時は次工程へ進めない条件を含める。

失敗シグナル:

- 自動承認を確定仕様として扱う。
- 矛盾をリスクや未決事項へ落とさない。

### CASE-RQ-003: セキュリティと機微情報

入力Minutes要約:

- Discordログにはメールアドレス、個人名、API keyらしき文字列が含まれる可能性がある。
- 議事録とRequirementには機微情報を直接残さず、監査ログは保持したい。
- MVPではSSOは非スコープだが、将来の認証連携を考慮したい。

期待される出力:

- `non_functional_requirements`: secret scan、PIIマスキング、監査ログ、権限境界を含める。
- `out_of_scope`: SSO実装はMVP外とする。
- `risks`: 情報漏えい、過剰ログ保存、外部AIへの機微情報送信を含める。
- `acceptance_criteria`: secretらしき値をRequirement本文に残さないことを検証可能にする。

失敗シグナル:

- API keyらしき値を本文に再掲する。
- セキュリティ要件を一般論だけで済ませる。

### CASE-RQ-004: API駆動開発への接続

入力Minutes要約:

- 要件定義が承認されたらOpenAPI案を作る。
- OpenAPIと実装が乖離したら完了扱いにしない。
- BackendはRails API、FrontendはNext.jsを想定するが、今回の議論はRequirement品質まで。

期待される出力:

- `functional_requirements`: approved RequirementをOpenAPI生成条件にする。
- `acceptance_criteria`: OpenAPI生成前にRequirement reviewが完了していることを含める。
- `out_of_scope`: Backend/Frontend実装は今回のRequirement生成評価セット外にする。

失敗シグナル:

- 実装タスクに踏み込み、IssueなしでBackend/Frontend作業を要求する。
- OpenAPI先行ルールを無視する。

### CASE-RQ-005: 情報不足の短い会議

入力Minutes要約:

- 「AIで要件を作りたい。次回までに案を見たい」
- 予算、利用者、入力データ、承認者、成功条件は未定。

期待される出力:

- `background`と`goal`は保守的に短くまとめる。
- `open_questions`: 利用者、入力形式、成功指標、承認者、非スコープを列挙する。
- `risks`: 情報不足により誤ったスコープで実装されるリスクを明記する。

失敗シグナル:

- 利用者、予算、成功指標を推測で補う。
- 詳細な機能要件を大量に作る。

### CASE-RQ-006: UXと運用要件が強い会議

入力Minutes要約:

- レビュー担当はRequirement差分、未決事項、リスクを短時間で確認したい。
- CI上で品質低下を検知し、合格しない生成結果はIssue化しない。
- ただし、初期MVPでは自動採点は警告扱いでよい。

期待される出力:

- `non_functional_requirements`: レビュー容易性、差分確認、CI警告、監査性を含める。
- `acceptance_criteria`: 合格基準未満ならIssue化不可または警告表示を検証可能にする。
- `out_of_scope`: 初期MVPでの完全自動ブロックは除外する。

失敗シグナル:

- UX要件を機能要件から落とす。
- 自動採点を初期から絶対ブロックとして扱う。

## 採点rubric

各サンプルケースを100点満点で採点する。採点時は、会議内容にない推測を高得点にしない。

| 観点 | 配点 | 満点条件 | 0点条件 |
| --- | ---: | --- | --- |
| 会議内容への忠実性 | 15 | 重要発言、決定、制約を過不足なく反映する | 会議にない決定や数値を作る |
| 必須項目の網羅と構造 | 10 | 対象出力項目が適切に埋まり、粒度が揃う | 必須項目が欠落する |
| 根拠追跡性 | 12 | どのMinutes内容に基づくかレビューで追える | 妥当性確認に議事録全文の再読が必要 |
| 未決事項と矛盾検出 | 12 | 曖昧さ、矛盾、承認待ちをopen questionsへ落とす | 未決を確定仕様に変える |
| 受け入れ条件の検証可能性 | 12 | テスト可能で、成功/失敗が判定できる | 抽象表現だけで検証できない |
| スコープ制御と幻覚耐性 | 12 | 非スコープを明示し、過剰実装を防ぐ | スコープ外機能を要求に含める |
| 非機能、セキュリティ、監査 | 10 | データ、権限、ログ、運用、UXをリスクに応じて含む | 機微情報や監査要件を無視する |
| Issue/OpenAPI readiness | 10 | 次工程のIssue化、API設計に使える粒度である | 実装者が再要件定義しないと使えない |
| 文体とレビュー容易性 | 5 | 簡潔で重複が少なく、レビュアーが差分確認しやすい | 長文、重複、曖昧語が多い |
| 生成元追跡 | 2 | provider/model/prompt versionを追える | 生成元が不明 |

## 合格基準

- 評価セット平均: 85点以上
- 各ケース: 78点以上
- P0観点である「会議内容への忠実性」「未決事項と矛盾検出」「受け入れ条件の検証可能性」「スコープ制御と幻覚耐性」「非機能、セキュリティ、監査」は、それぞれ配点の80%以上
- Critical failureが1件もない
- レビュアーがP0修正なしでRequirement reviewへ進められる

Critical failure:

- 会議にない意思決定、期限、顧客名、数値を確定事項として生成する
- 機微情報、secret、個人情報を必要以上に再掲する
- レビュー未完了なのにIssue生成、OpenAPI生成、実装へ進める前提を作る
- 明示された非スコープをRequirementに含める
- 矛盾した発言を未決事項にせず、片方を勝手に採用する

## 失敗時の改善アクション

| 失敗パターン | 改善アクション |
| --- | --- |
| 幻覚や過剰補完が多い | promptに「Minutesにない事実はopen_questionsへ送る」を追加し、根拠なし断定を減点する |
| 未決事項が弱い | ambiguity checklistを導入し、actor、承認者、入力、出力、成功指標、非スコープを必ず確認する |
| 受け入れ条件が抽象的 | Given/When/Then変換ルールを追加し、テストで判定できない文を減点する |
| セキュリティ観点が抜ける | STRIDE/OWASP観点をRequirement生成promptとレビューrubricに組み込む |
| スコープが膨らむ | out_of_scope抽出を独立ステップにし、MVP外をRequirement本文から分離する |
| Issue/OpenAPIに使いにくい | actor、状態、入力、出力、例外、データ項目をfunctional requirementsへ分解する |
| 長文でレビューしにくい | 重複削除、最大項目数、1項目1意図の整形ルールを追加する |
| 機微情報を再掲する | secret scanとPII redactionを生成前後に適用し、検出時はreview_requiredにする |

## 今後の自動化案

1. OpenAPIのRequirement schemaに対する構造チェックを自動化する。
2. LLM judgeと人間レビューの2段階評価にし、外部AIレビュー待ちの場合は明記する。
3. CIでは初期はwarningとして実行し、3回連続で安定したらblocking gateへ昇格する。
4. provider、model、prompt version、score差分をartifactとして保存する。
5. レビューUIで人間の修正差分を収集し、golden datasetの更新候補として扱う。

## 2026-07-06 baseline結果

2026-07-06に、サンプルMinutes、期待語、最小件数、禁止pattern、P0カテゴリを `docs/evaluation/fixtures/requirement_generation/cases.json` としてfixture化した。

`scripts/evaluate-requirement-generation.rb` により、現行deterministic providerを同一条件で採点できるようにした。実行コマンドは以下である。

```bash
npm run requirements:evaluate -- --output docs/evaluation/20260706_requirement_generation_baseline.md --quiet
```

初回baselineは以下である。

| 指標 | 結果 |
| --- | --- |
| Provider | deterministic |
| 平均点 | 91.0 / 100 |
| ケース別最低点 | 79.2 / 100 |
| Critical failure | 0件 |
| P0基準未達 | 6件 |
| 判定 | 基準未達 |

P0未達の中心は、スコープ制御と非機能要件である。特に、SSO、Backend、Frontend、実装、CI警告、監査性、PII、secret、権限といった会議内の制約を、`out_of_scope` と `non_functional_requirements` へ安定して反映できていない。

provider改善後のbaselineは以下である。

```bash
npm run requirements:evaluate -- --output docs/evaluation/20260706_requirement_generation_provider_rules_baseline.md --quiet
```

| 指標 | 結果 |
| --- | --- |
| Provider | deterministic |
| 平均点 | 100.0 / 100 |
| ケース別最低点 | 100.0 / 100 |
| Critical failure | 0件 |
| P0基準未達 | 0件 |
| 判定 | 合格 |

改善では、非スコープ抽出と非機能要件抽出を強化した。あわせて、providerインスタンス再利用時に前回Minutesのsource textが残る不具合を修正した。

## 運用判定

この評価セットはIssue #3の「Requirement生成品質評価セット」を実行可能な状態にしたものである。fixture化、採点自動化、実生成結果の初回baseline取得、deterministic provider改善後baseline取得は完了した。

現行fixture上ではP0基準未達は0件である。ただし、Issue #3全体の完了条件には以下を含め続ける。

- approved RequirementとIssue/OpenAPI生成条件の接続
- Review Centerのresolved状態とRequirement承認条件の接続
- OpenAI provider導入時の同fixture比較
- fixture外の実データでの追加検証
