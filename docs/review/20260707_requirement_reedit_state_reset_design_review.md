# Requirement再編集時の承認状態戻し 設計レビュー

## 評価日時

2026-07-07 05:19 JST

## 評価担当

Codexレビュー統括 / Tech Lead / Backend Architect / Frontend Architect / Security Engineer / QA

外部AIレビュー: Claude、ChatGPTレビューは未実施。現時点ではCodex一次レビューとして保存し、外部AIレビュー結果が追加された場合は差分分析を追記する。

## 使用フレームワーク

- G-STACK
- STRIDE
- DDD
- ISO25010
- MoSCoW

## 対象

Issue #3のRequirement承認後に内容を再編集した場合、古い承認状態のままIssue/OpenAPI生成へ進めないようにする設計を評価する。

## 良かった点

- 既存status enumに `needs_changes` があり、新しい状態を増やさずに承認無効化を表現できる。
- Issue/OpenAPI生成APIはRequirement `approved` を要求しているため、再編集時に `needs_changes` へ戻せば下流工程も自然に停止できる。
- `approved_by`、`approved_at`、`approval_note` が追加済みのため、再編集時に承認メタデータを消すことで「再承認が必要」を明確にできる。
- OpenAPIの `UpdateRequirementRequest.status` を削除し、Controllerで `status` 直接更新を拒否すれば、承認APIやレビュー操作を迂回する状態変更リスクを下げられる。

## 改善点

- 更新差分の判定をControllerへ直接書くと、今後の監査粒度追加でControllerが肥大化する。
- 承認コメント本文をAuditLogへ保存すると情報露出が増えるため、無効化時もコメント本文は保存しない方がよい。
- 今回は差分本文の保存までは行わず、変更フィールド名に留めるため、完全な差分履歴にはならない。
- Frontendでは保存後のstatus chipで `needs_changes` は表示されるが、専用の「再承認が必要」説明はまだ薄い。

## 優先順位

| 優先度 | 指摘 | 改善案 |
| --- | --- | --- |
| P0 | PATCHで `status` を直接更新できる | `UpdateRequirementRequest` とstrong paramsから `status` を外し、Controllerでstatus直接更新を拒否する |
| P0 | 承認済みRequirementの実質変更後もapprovedが残る | 重要フィールド変更時に `needs_changes` へ戻し、承認メタデータをnilにする |
| P1 | AuditLogの差分粒度 | 本文は保存せず、changed_fields、approval_invalidated、previous_statusをmetadataへ残す |
| P2 | UI説明不足 | 後続で再承認が必要な理由とblocker詳細をRequirement Workspaceへ表示する |

## 次アクション

1. `RequirementUpdateService` を追加し、更新属性、変更フィールド、承認無効化判定をまとめる。
2. `RequirementsController#update` はService呼び出しとAuditLog保存に限定する。
3. OpenAPIと生成型から `UpdateRequirementRequest.status` を削除する。
4. Request specでstatus直接更新の拒否、承認済みRequirement再編集時の `needs_changes`、承認メタデータ消去、AuditLog metadataを確認する。
5. Frontend E2Eで、承認後の再保存によりIssue/OpenAPI生成ボタンが再度無効化されることを確認する。

## Issue番号

- GitHub Issue: #3

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | 承認済みRequirementが再編集された場合、古い承認で下流工程へ進めないようにする |
| Strategy | 更新Serviceで実質変更を検出し、承認状態と承認メタデータを無効化する |
| Tactics | strong paramsからstatus除外、OpenAPI更新、Service Object、request spec、E2E |
| Assessment | 設計は妥当。ただし完全な差分履歴ではなく、今回は承認無効化と監査metadataに限定する |
| Conclusion | 実装へ進めてよい。Security観点ではstatus直接更新の除外をP0として扱う |
| Knowledge | レビューゲートは承認時だけでなく、承認後の変更でも守らないと実質的な統制にならない |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | PATCHで承認者を偽装する経路はない | 承認者は承認APIのみで更新する |
| Tampering | PATCHでstatusを直接変更できる可能性 | statusをUpdateRequirementRequestとstrong paramsから外し、Controllerでも拒否する |
| Repudiation | 再編集で承認無効化された証跡が必要 | AuditLog metadataへ変更フィールドと無効化有無を保存する |
| Information Disclosure | 差分本文や承認コメント本文をログへ保存すると露出が増える | metadataはフィールド名とコメント有無に限定する |
| Elevation of Privilege | writerがreviewer承認を迂回できる可能性 | `approve` APIだけがapprovedへ遷移できる設計に寄せる |

## 判定

実装へ進めてよい。今回の完了条件は、status直接更新の遮断、承認済みRequirement再編集時の `needs_changes` 遷移、承認メタデータ消去、監査metadata、OpenAPI同期、Backend/Frontend検証までとする。
