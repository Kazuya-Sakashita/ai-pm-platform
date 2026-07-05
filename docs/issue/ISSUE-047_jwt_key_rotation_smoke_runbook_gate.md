# ISSUE-047: JWT key rotation staging smokeとproduction runbook gateを整備する

## Issue番号

ISSUE-047

## GitHub Issue

https://github.com/Kazuya-Sakashita/ai-pm-platform/issues/47

登録日: 2026-07-06

## 背景

ISSUE-042でJWT key rotation runbookを作成したが、staging/production環境でのsmoke、monitoring、release gate、emergency key compromise手順はまだ実証されていない。

## 目的

JWT key rotationを運用可能にするため、staging smoke、production release gate、monitoring/alert、evidence保存手順を整備する。

## 完了条件

- staging normal rotation smoke手順が実行または実行待ち理由付きで保存されている
- emergency compromised `kid` disable手順がある
- rollback可能期間とrollback禁止条件が定義されている
- monitoring/alert項目が定義されている
- production release gateにkeyring validationが入っている
- evidence templateが `docs/review/` に保存できる
- DevOps/Securityレビューが `docs/review/` に保存されている

## スコープ

- Runbook hardening
- staging smoke
- release gate
- monitoring/alert checklist
- CI/CD validation方針
- emergency operation evidence

## 非スコープ

- keyring backend implementation
- IdP/JWKS integration
- cloud provider specific KMS implementation

## 関連レビュー

- `docs/review/20260706_jwt_revocation_session_key_rotation_design_review.md`

## 関連ADR

- `docs/decisions/ADR-0017_jwt_revocation_session_key_rotation.md`

## レビュー結果

Security/DevOps Agentは、normal rotation、emergency key compromise、unknown/retired `kid` monitoring、production misconfiguration gateをP1運用要件として指摘した。

## 優先度

P1

理由:

- keyringを実装してもrotationを実証しなければproduction trustに届かない
- key compromise時の初動が遅れると全API trustが崩れる
- release gateに組み込むことで設定ミスを早期に止められる

## 次アクション

1. ISSUE-045のkeyring実装後にstaging smokeを設計する。
2. production release gate checklistを追加する。
3. CI/CDまたはdeploy preflightのvalidationをIssue化または実装する。
