# Expert subagent pilot review for ISSUE-039

## 評価日時

2026-07-05 17:25:00 JST

## 評価担当

Codex as Review Orchestrator / Security Engineer / QA / CTO / Product Owner / AI Architect / Backend Architect / Frontend Architect / DevOps

## 使用フレームワーク

- G-STACK
- STRIDE
- OWASP Top 10
- ISO25010
- DDD
- OpenAPI
- RICE

## Issue番号

- ISSUE-039
- GitHub Issue: https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/39
- Pilot parent Issue: ISSUE-041

## 評価対象

ISSUE-039: 実認証/JWT actor identity接続を実装する

関連現状:

- DM系APIは `X-Actor-Id` を暫定actor identityとして使っている。
- `docs/api/openapi.yaml` にはBearer JWT security schemeが存在するが、DM系APIには一部 `X-Actor-Id` header parameterが残っている。
- Frontend API clientは `NEXT_PUBLIC_ACTOR_ID` または `local-demo-owner` を使い、`X-Actor-Id` を送っている。
- AuditLog actor_idはDM操作では暫定actorに接続されている。

## 参加Agent

| Agent | Mode | 判定 |
| --- | --- | --- |
| Security Engineer + QA Agent | Codex subagent Avicenna | action_required |
| Product Owner + CTO + AI Architect Agent | Codex subagent Dewey | action_required |
| Review Orchestrator | Codex primary | action_required |
| Backend/Frontend/DevOps role-separated experts | Codex primary | conditional inputs defined |

## Agent別サマリー

### Security Engineer + QA Agent

重点指摘:

- `X-Actor-Id` をproduction pathで信頼しないことをP0条件にする。
- 未認証、不正token、期限切れtoken、project非member、role不足、cross-project accessをrequest specで固定する。
- AuditLog actor_idは認証済みuser idから導出し、client指定値を保存しない。
- JWT secret、issuer、audience、clock skew、revocation相当の扱いをADRへ記録する。
- 再現可能なCI検証とsafe error contractを必須にする。

### Product Owner + CTO + AI Architect Agent

重点指摘:

- 認証/JWTはAI PM Platformのenterprise trustを成立させる基盤であり、MVPでも回避できない。
- 一方でSSO/SAMLや組織RBACへ広げるとスコープが膨らむため、ISSUE-039ではsingle-tenant相当のJWT/session境界に絞る。
- AI操作、DM整理、Review承認、Issue生成を「誰が実行したか」と結びつけることで、AI PMの差別化になる。
- OpenAPI、Frontend client、AuditLog、Policy Objectの順で契約を揃え、後続のmembership UIへ接続する。

## 統合判定

action_required。

ISSUE-039は実装へ進める前に、認証方式ADR、OpenAPI security schemeの適用範囲、`X-Actor-Id` 廃止境界、AuditLog actor mapping、safe error contractを明確にする必要がある。

## 良かった点

- ISSUE-039はP0 blockerとして粒度が適切で、Project membership管理やReview Center連動より先に進めるべき対象である。
- 既存のPolicy Objectとproject membershipがあるため、認証済みidentityへ置換する土台はある。
- OpenAPIにはBearer JWT security schemeの下地があり、契約更新の入口がある。
- AuditLogがすでに存在するため、actor identityを接続する価値が大きい。

## 改善点

- `X-Actor-Id` の暫定利用範囲と廃止条件をADRに明記する必要がある。
- token検証の方式、issuer、audience、expiry、test key、local dev bypassの扱いが未定である。
- Frontendの再ログイン導線とAPI clientの認証ヘッダー方針が未設計である。
- request specの失敗系はDM系APIに集中しつつ、Projects APIなどactorを使う既存APIへの影響も確認が必要である。
- AuditLogにuser idだけを残すか、display name/email hashなどをmetadataへ持つかの方針が未定である。

## 優先順位

| Priority | 指摘 | 対応 |
| --- | --- | --- |
| P0 | production pathで `X-Actor-Id` を信頼しない | ISSUE-039内で対応 |
| P0 | 未認証、不正token、期限切れ、非memberをsafe errorで拒否する | ISSUE-039内で対応 |
| P0 | AuditLog actor_idを認証済みuser idへ接続する | ISSUE-039内で対応 |
| P1 | OpenAPI security schemeをDM系APIとProjects APIへ適用する | ISSUE-039内で設計 |
| P1 | Frontend再ログイン導線を日本語で実装する | ISSUE-039内または分割Issue |
| P2 | token revocation/session invalidationの本番設計を深める | 後続Issue候補 |

## 次アクション

1. ISSUE-039の最初に認証方式ADRを作成する。
2. OpenAPIでBearer JWT security schemeと `X-Actor-Id` 廃止対象を明記する。
3. Backend request specで未認証、不正token、期限切れtoken、非member、role不足、cross-project accessを先に追加する。
4. Frontend API clientの認証ヘッダーと401/403日本語導線を設計する。
5. 実装後、専門家サブエージェントレビューを再実施する。

## 衝突分析

| 衝突 | 判断 |
| --- | --- |
| Product観点では早くUI導線へ進みたいが、Security/QAは認証をP0 blockerとする | Security/QAを採用。認証済みidentityなしではAI操作と監査の信頼性が成立しない |
| CTO観点では将来SSO/SAMLも見たいが、MVP scopeが膨らむ | ISSUE-039ではJWT/session境界に絞り、SSO/SAMLは非スコープ維持 |
| Frontendではlocal demoを維持したいが、productionで任意actor headerは危険 | local/test helperとしてのみ残し、production pathでは認証済みcontextから導出する |

## G-STACK

| 項目 | 評価 |
| --- | --- |
| Goal | `X-Actor-Id` 依存を解消し、AI PM操作を認証済みuserへ接続する |
| Strategy | ADR、OpenAPI、request specを先に固定してから実装へ進む |
| Tactics | JWT/session境界、safe error、AuditLog mapping、Frontend再ログイン導線 |
| Assessment | ISSUE-039は次に進めるべきP0。ただし実装前レビュー条件がある |
| Conclusion | #39を次の実装対象にする。#41のパイロットとして専門家レビューは有効 |
| Knowledge | AI PMでは「AIが何をしたか」だけでなく「誰の権限でAI操作が走ったか」を監査できる必要がある |

## 判定

パイロット成功。専門家サブエージェントレビューにより、ISSUE-039の実装前にP0条件、scope境界、test contract、AuditLog接続、Frontend導線の論点を分離できた。

## AIレビュー比較

Codex primaryとCodex subagentレビューを実施。Claude、ChatGPTなど外部AIレビューは未実施。外部レビューが追加された場合は、JWT方式、token失効、AuditLog actor mapping、local dev bypassの扱いを比較する。
