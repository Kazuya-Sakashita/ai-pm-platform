# Requirement再編集時の承認状態戻しレビュー

## 評価日時

2026-07-07 05:20 JST

## 評価担当

Codexレビュー統括 / Tech Lead / Backend Architect / Security Engineer / QA / Product Manager

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- ISO25010
- MoSCoW
- DDD

## Issue番号

- GitHub Issue: #3

## 対象成果物

- `backend/app/services/requirement_revision_service.rb`
- `backend/app/controllers/api/v1/requirements_controller.rb`
- `backend/spec/services/requirement_revision_service_spec.rb`
- `backend/spec/requests/api/v1/requirements_spec.rb`
- `docs/api/openapi.yaml`
- `frontend/e2e/meeting-workspace.spec.ts`
- `frontend/lib/api/schema.d.ts`

## 評価サマリー

承認済みRequirementのレビュー対象フィールドが再編集された場合、`status` を `needs_changes` に戻し、`approved_at`、`approved_by`、`approval_note` をクリアする制御を追加した。さらに、PATCHで `status` を直接送って状態遷移APIを迂回する経路を422で拒否する。

これにより、承認後に内容が変わったRequirementが承認済みのままIssue生成やOpenAPI生成へ進むリスクを下げる。

## 良かった点

- 差分検知と承認リセットを `RequirementRevisionService` に分離し、Controllerの責務を薄く保った。
- 承認済みRequirementの重要フィールド変更時に、古い承認メタデータをクリアするようにした。
- AuditLog metadataへ `changed_fields` と `approval_reset` を残し、なぜ差し戻されたか追跡できる。
- PATCHによる直接status更新を拒否し、承認や差し戻しは専用API、レビュー操作、再編集差分検知を通るようにした。
- service specとrequest specで、差し戻し、差分なし維持、直接status更新拒否を確認した。

## 改善点

- 差分履歴はAuditLog metadataに留まり、変更前後の値までは保存していない。
- Frontendでは保存後に `needs_changes` へ戻るが、なぜ戻ったかを明示する専用メッセージはまだない。
- どのフィールドをレビュー対象にするかはService定数で固定しており、将来フィールド追加時の見落としリスクがある。
- 承認済みRequirementから下流に生成済みのIssue/OpenAPI draftをどう扱うかは未整理。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | 下流draftの stale 化が未実装 | Requirement差し戻し時に関連Issue/OpenAPI draftの扱いを設計する |
| P1 | UIで差し戻し理由が弱い | 保存完了メッセージに承認状態が戻った理由を表示する |
| P1 | 差分履歴が弱い | 重要フィールドの変更前後を安全に記録する方式を検討する |
| P2 | REVIEWED_FIELDS追加漏れリスク | schemaまたはmodel側と連動したテストを追加する |

## 次アクション

1. PR CIでbackend、OpenAPI、frontend build、E2Eを確認する。
2. Requirement Workspaceで未解決Review件数と承認blocker詳細を表示する。
3. Requirement差し戻し時の下流Issue/OpenAPI draft stale化ルールを設計する。
4. OpenAI provider比較に進む前に、provider非依存で承認状態戻しが動くことを確認する。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 承認後に内容が変わったRequirementを承認済みのまま次工程へ流さない |
| Strategy | 更新時の差分検知をService化し、承認メタデータを安全に失効させる |
| Tactics | 重要フィールド差分、`needs_changes` への状態戻し、承認メタデータクリア、直接status更新拒否を追加 |
| Assessment | 監査と承認ゲートの一貫性は改善した。ただし下流draftの扱いは未完了 |
| Conclusion | 条件付き合格。Issue #3のP0抜け道は一段塞げた |
| Knowledge | 承認は成果物の特定バージョンに対する判断であり、内容が変わったら承認も失効する |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | PATCHで承認者を偽る経路はない | 承認はapprove APIへ限定 |
| Tampering | 承認後編集が承認済みのまま残る問題を抑止 | 重要フィールド変更時に `needs_changes` へ戻す |
| Repudiation | 差し戻し理由をAuditLog metadataへ保存 | `changed_fields` と `approval_reset` を記録 |
| Information Disclosure | 変更前後の本文はAuditLogへ保存していない | 詳細差分保存時は機微情報対策が必要 |
| Elevation of Privilege | PATCHの直接status更新を拒否 | 承認ロールと承認ゲートを通す |

## ISO25010

| 品質特性 | 評価 |
| --- | --- |
| 機能適合性 | 承認済み再編集の状態戻し要件を満たした |
| 信頼性 | service/request specで主要分岐を確認している |
| セキュリティ | 承認API迂回を拒否し、古い承認メタデータをクリアする |
| 保守性 | 差分検知をServiceへ分離した |
| 使用性 | UIの理由表示には改善余地がある |

## MoSCoW

| 区分 | 内容 | 状態 |
| --- | --- | --- |
| Must | 承認済みRequirement再編集時の `needs_changes` 戻し | 完了 |
| Must | 古い承認メタデータのクリア | 完了 |
| Must | PATCH直接status更新拒否 | 完了 |
| Should | UI上の差し戻し理由表示 | 未完了 |
| Should | 下流draft stale化 | 未完了 |
| Could | 変更前後差分履歴 | 未完了 |

## 検証結果

- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec rspec spec/services/requirement_revision_service_spec.rb spec/services/requirement_approval_gate_spec.rb spec/requests/api/v1/requirements_spec.rb spec/requests/api/v1/issue_drafts_spec.rb spec/requests/api/v1/open_api_drafts_spec.rb`: 51 examples, 0 failures
- `PATH=/Users/kazuya/.rbenv/versions/3.2.2/bin:$PATH bundle exec ruby bin/rails zeitwerk:check`: All is good
- `npm run api:verify`: 成功。OpenAPI validation成功。Node version warningのみ既知
- `npm run display:check`: 成功
- `npm run frontend:build`: 成功
- `npm run frontend:e2e -- --grep "creates a project, saves a Discord log, generates minutes, and requests review"`: 1 passed

## 判定

条件付き合格。承認済みRequirement再編集時の状態戻しは実装できた。ただし、PR CI、UI上の差し戻し理由表示、下流draft stale化が残るためIssue #3は継続する。
