# JWT revocation follow-up issue split review

## 評価日時

2026-07-05 17:56:01 JST

## 評価担当

Codex as Review Orchestrator / Security Engineer / QA / CTO / Backend Architect / Product Manager

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- RICE
- ISO25010

## Issue番号

- ISSUE-042
- Parent context: ISSUE-039

## 評価対象

- `docs/decisions/ADR-0016_jwt_actor_identity_for_api_audit.md`
- `docs/review/20260705_auth_jwt_actor_identity_implementation_review.md`
- `docs/issue/ISSUE-042_jwt_revocation_session_key_rotation.md`

## 良かった点

- ISSUE-039ではP0である任意header spoofing排除を優先し、revocationを無理に混ぜずにscopeを守った。
- ADR-0016でrevocation/replayを明示的にリスク受容しており、残課題が暗黙化していない。
- token失効、session version、key rotationは設計粒度が大きく、独立Issueに分ける判断が妥当である。

## 改善点

- 現時点では漏えいした有効期限内tokenを即時失効できない。
- secret/key rotationの旧key許容期間、rollback、監査ログ方針が未定である。
- Frontendのtoken expired/revoked時の再ログイン導線は文言対応のみで、session復旧フローは未設計である。
- 外部IdP/JWKSへ移行する場合のclaim互換性が未整理である。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P1 | token revocation/session version/key rotationを設計する | ISSUE-042 |
| P1 | safe error contractにrevoked/session invalidを追加する | ISSUE-042 |
| P1 | rotation監査ログとrollback方針を決める | ISSUE-042 |
| P2 | external IdP/JWKS移行の互換性を整理する | ISSUE-042または後続 |

## 次アクション

1. ISSUE-042をGitHub Issueへ登録する。
2. ISSUE-039のクローズ条件には含めず、P1 follow-upとして管理する。
3. ISSUE-040と並行可能な設計タスクとして扱う。

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | JWT actor identityをproduction運用に耐える失効/rotation設計へ進める |
| Strategy | ISSUE-039から分離し、Security/Backend中心の設計Issueとして扱う |
| Tactics | session version、`jti`、revocation list、key rotation、safe error、AuditLogを比較 |
| Assessment | P0ではないがenterprise trustには必要。P1 follow-upが妥当 |
| Conclusion | ISSUE-042として切り出す |
| Knowledge | 認証は「通す」だけでなく「止める」「戻す」「監査する」設計まで含めてproduction qualityになる |

## STRIDE / OWASP観点

| 観点 | リスク | 対応 |
| --- | --- | --- |
| Spoofing | 漏えいtokenの期限内再利用 | revocation/session version検討 |
| Repudiation | 失効/rotation操作の監査不足 | AuditLog/operation log方針を設計 |
| Elevation of Privilege | 管理者権限token漏えい時の即時停止不可 | logout everywhere/forced revokeを設計 |
| OWASP A07 | Identification and Authentication Failures | token lifecycleを明確化 |
| OWASP A09 | Security Logging and Monitoring Failures | 失効/拒否/rotation eventを記録 |

## 判定

合格。ISSUE-042として切り出し、ISSUE-039の完了を妨げないP1 follow-upとして管理する。

## AIレビュー比較

Codex primaryによる一次レビュー。ISSUE-039のCodex subagent Ramanujan/Booleの指摘を根拠にした。Claude、ChatGPTなど外部AIレビューは未実施。
