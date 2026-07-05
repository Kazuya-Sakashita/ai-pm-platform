# Discord DM Project Membership / Policy Object 設計レビュー

## 評価日時

2026-07-05 13:58:56 JST

## 評価担当

Codex / Security Engineer / CTO / Backend Architect / Frontend Architect / QA / Product Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010

## 対象

- GitHub Issue: #30
- `docs/security/20260705_discord_dm_project_membership_policy.md`

## 良かった点

- 暗号化だけでは防げないAPI経由のBroken Access ControlをP0として扱った。
- role matrixを操作単位で定義し、viewer/editor/reviewer/adminの責務を分けた。
- `X-Actor-Id` を暫定identityとして明示し、将来の認証済みuser idへ差し替える前提を文書化した。
- safe 403 responseでDM本文、project名、DMタイトル、参加者、role詳細を返さない方針にした。
- AuditLog actorを `system` 固定から将来の実ユーザーIDへ接続できる形にした。

## 改善点

- `X-Actor-Id` は認証ではないため、production securityとしては不十分。
- Project一覧やMeeting/Requirement/GitHub連携APIには今回の認可が横展開されない。
- Project membership管理APIは未実装であり、初期メンバー作成はProject作成時のowner付与に限られる。
- reviewer/editorの職務分掌はMVPとして妥当だが、企業導入時はOrganization role、SSO group、監査者の閲覧範囲が必要。

## 優先順位

| 優先度 | 内容 | 理由 |
| --- | --- | --- |
| P0 | DM関連APIのproject membership強制 | DM本文の不正閲覧/削除を防ぐ |
| P0 | request specで他project/非member/readonly/承認不可を検証 | Broken Access Control回帰を防ぐ |
| P0 | AuditLog actor_idを暫定actorへ接続 | 監査証跡の起点 |
| P1 | Frontendへ暫定actor headerを付与 | 既存UIが403で破綻しないようにする |
| P1 | Project membership管理API | 別Issue候補 |
| P1 | 認証基盤/JWT接続 | ISSUE-006系で継続 |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | DM本文/整理結果のAPIアクセスをproject membershipで制御する |
| Strategy | DM系APIへ限定してPolicy Objectを導入し、既存MVPの破壊範囲を抑える |
| Tactics | `project_memberships`、`ConversationImportPolicy`、safe 401/403、request spec、OpenAPI header |
| Assessment | P0のDM漏えいリスクを下げる。実認証と横展開は残課題 |
| Conclusion | 条件付きで実装へ進める |
| Knowledge | OWASP A01、STRIDE、ISSUE-029/032のDMデータ保護方針 |

## STRIDE

| 脅威 | 評価 | 対応 |
| --- | --- | --- |
| Spoofing | `X-Actor-Id` は偽装可能 | MVP暫定。productionでは認証済みuser idへ置換 |
| Tampering | editor/reviewerが権限外操作を実行する | Policy Objectでactionごとに拒否 |
| Repudiation | actor不明のDM操作 | actor header必須化とAuditLog actor_id記録 |
| Information Disclosure | 非member/他projectのDM閲覧 | read actionをmembership必須にする |
| Denial of Service | admin以外の匿名化実行 | anonymizeはowner/adminのみ |
| Elevation of Privilege | viewerが承認/削除する | role matrixで拒否、specで回帰防止 |

## OWASP Top 10

| 項目 | 評価 |
| --- | --- |
| A01 Broken Access Control | 本Issueの主対象。DM系APIで改善 |
| A02 Cryptographic Failures | 暗号化済みデータもAPI経由で漏れるため、認可を追加 |
| A04 Insecure Design | 操作別権限表を文書化し、実装前レビューを保存 |
| A09 Security Logging and Monitoring Failures | AuditLog actor接続で改善 |

## ISO25010

| 品質特性 | 評価 |
| --- | --- |
| Security | 大幅改善。ただし実認証は未完 |
| Compatibility | Frontendへdefault actor headerを入れ、既存UIを維持 |
| Maintainability | Policy Objectでcontroller条件分岐を抑える |
| Testability | role別request specで検証可能 |

## 次アクション

1. `project_memberships` migration/model/factoryを追加する。
2. `ConversationImportPolicy` とcontroller guardを実装する。
3. OpenAPIに `X-Actor-Id` と403 responseを追加する。
4. Frontend API clientへ暫定actor headerを追加する。
5. request spec / api verify / frontend e2eを実行し、実装レビューを保存する。

## Issue番号

- #30
