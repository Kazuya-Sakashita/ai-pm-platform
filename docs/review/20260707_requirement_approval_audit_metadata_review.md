# Requirement承認メタデータ 実装レビュー

## 評価日時

2026-07-07 05:10 JST

## 評価担当

Codexレビュー統括 / Product Manager / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- MoSCoW
- DDD

## 対象

Issue #3のRequirement承認に、承認者、承認日時、承認コメントを保存し、OpenAPI、Backend、Frontend、E2E、監査ログへ接続する変更を評価する。

## 良かった点

- `requirements` に `approved_at`、`approved_by`、`approval_note` を追加し、承認結果をAuditLogだけに依存しない形で永続化した。
- 承認APIで `approval_note` を必須化し、レビュー済みである理由を人間が明示するワークフローにした。
- AuditLogには承認コメント本文を保存せず、`approval_note_present` のみを残してログ上の不要な情報露出を避けている。
- OpenAPIに `ApproveRequirementRequest` と422レスポンスを追加し、Frontend型定義も同期されている。
- Requirement Workspaceで承認コメント入力、承認者、承認日時、承認コメントを確認でき、レビュー結果から下流工程へ進む根拠がUI上でも追える。
- RSpecで成功系、承認コメント欠落、未解決レビュー、期限切れrisk acceptance、project境界、下流Issue/OpenAPIドラフト生成gateを確認している。

## 改善点

- 承認後にRequirementを再編集した場合、`approved` から `needs_changes` へ戻す状態遷移がまだない。
- 承認コメントは自由文のみで、承認観点、残リスク、次工程許可範囲を構造化していない。
- 承認履歴は最新値のみで、過去承認、再承認、差分履歴を時系列で追跡できない。
- Frontendでは承認メタデータを表示できるが、未解決Review件数、blocker理由、accepted_risk期限を承認前に強く可視化するには不足している。
- 外部AI複数レビューは未実施で、Codex一次レビューに留まっている。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | 再編集後も承認済みのまま残る可能性 | Requirement更新時に重要フィールド差分を検知し、`needs_changes` へ戻す |
| P1 | 承認履歴が最新値のみ | `requirement_approvals` またはAuditLog詳細で再承認履歴を追えるようにする |
| P1 | 承認前のblocker視認性が弱い | Workspaceに未解決Review件数、期限切れrisk acceptance、blocker詳細を表示する |
| P2 | 承認コメントが自由文のみ | 承認理由、残リスク、次工程許可範囲のテンプレート化を検討する |
| P2 | 外部AIレビュー未実施 | Claude/ChatGPTレビュー結果を取得できた時点で差分分析を追記する |

## 次アクション

1. Requirement再編集時の状態戻しをIssue #3の次候補として設計、実装する。
2. Requirement Workspaceで未解決Review件数と承認blocker詳細を表示する。
3. OpenAI providerを導入する場合は、同じfixtureでdeterministic providerと比較する。
4. 承認履歴を複数回残す必要が出た段階で、専用テーブル化またはAuditLog詳細拡張をADR化する。

## Issue番号

- GitHub Issue: #3

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | Requirement承認の根拠を、誰が、いつ、どの理由で承認したかまで追跡可能にする |
| Strategy | 承認API、DB、OpenAPI、Frontend、AuditLogを同時に更新し、承認情報を下流工程の監査証跡にする |
| Tactics | `approval_note` 必須化、承認メタデータ追加、レスポンスschema拡張、UI表示、request spec、E2E確認 |
| Assessment | 監査可能性は前進した。ただし再編集時の状態戻しと承認履歴がないため、世界レベルSaaS基準では条件付き合格 |
| Conclusion | Issue #3の承認メタデータ追加は採用可能。次は再編集時の状態戻しとblocker詳細表示を優先する |
| Knowledge | AI PMでは「承認した」事実だけでなく、「なぜ次工程へ進めるか」を保存することが信頼の中核になる |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | `approved_by` は認証済みactorから導出される | request bodyから承認者を受け取らない方針を維持する |
| Tampering | 承認後の再編集で承認状態が古くなる | 更新時の状態戻しをP0で追加する |
| Repudiation | 承認者、承認日時、承認コメントをDBに保存 | AuditLogにも `approved_at` とコメント有無を残す |
| Information Disclosure | AuditLogへ承認コメント本文を保存しない | UI/APIの表示権限を認可境界で継続確認する |
| Denial of Service | 追加処理は軽量 | 監査履歴が増えた場合は専用テーブルとindexを再評価する |
| Elevation of Privilege | 承認APIは既存のproject権限に依存 | role別承認権限の粒度は後続RBACで改善する |

## ISO25010

| 品質特性 | 評価 |
| --- | --- |
| 機能適合性 | 承認コメント必須化とメタデータ保存により、監査要件に近づいた |
| 互換性 | OpenAPIと生成型を同期しており、Frontend/Backendの乖離は小さい |
| 使用性 | Workspace上で承認情報を確認できるが、blocker理由の視認性は改善余地がある |
| 信頼性 | request specで主要な失敗条件を確認している |
| セキュリティ | AuditLogへの本文保存を避け、project境界specも維持している |
| 保守性 | Controllerに過剰な業務処理を増やさず、既存gateと組み合わせている |

## MoSCoW

| 区分 | 内容 | 状態 |
| --- | --- | --- |
| Must | 承認者、承認日時、承認コメントを保存 | 完了 |
| Must | 承認コメントなしの承認拒否 | 完了 |
| Must | OpenAPIとFrontend型の同期 | 完了 |
| Should | UI上の承認メタデータ表示 | 完了 |
| Should | 再編集時の状態戻し | 未完了 |
| Could | 承認履歴の複数世代管理 | 未完了 |
| Won't now | 完全自動承認 | 非スコープ |

## 検証結果

- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_approval_gate_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 52 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI validation成功。Node version warningのみ既知
- `npm run frontend:build`: 成功
- `npm run display:check`: 成功

## 判定

条件付き合格。Requirement承認の監査粒度は明確に上がったため、PR化してよい。ただし、再編集時の状態戻し、承認履歴、blocker詳細表示が未完了であり、Issue #3は継続する。
