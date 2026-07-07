---
name: security-review
description: セキュリティレビュー用Skill。.env、認証、認可、ログ、CORS、RLS、シークレット管理、OWASP、STRIDE、監査ログ、PIIを確認するときに使う。
---

# Security Review

## Purpose

認証、認可、秘密情報、個人情報、監査性のリスクを実装前後で評価する。

## When to use

- 認証、認可、OAuth、GitHub App、OpenAI、ログ、データ削除を扱うとき。
- APIが外部入力やsecretを扱うとき。

## Inputs

- 変更差分。
- API contract。
- 環境変数、ログ、AuditLog方針。
- STRIDE/OWASP観点。

## Process

1. 認証済みactorの導出を確認する。
2. Project/role単位の認可を確認する。
3. `.env`、secret、token、API keyの保存/表示を確認する。
4. raw exception、backtrace、PIIがAPI/UI/logに出ないか確認する。
5. CORS、rate limit、replay、idempotencyを必要に応じて確認する。
6. AuditLogに安全なmetadataだけ残す。

## Output

- セキュリティ指摘。
- P0/P1 blocker。
- 改善案。
- レビュー文書。

## Constraints

- secretを出力に含めない。
- raw DM全文や不要PIIを保存しない。
- Security P0 blockerはリスク受容なしに進めない。

## Checklist

- [ ] 認証を確認した。
- [ ] 認可を確認した。
- [ ] secret/PII露出を確認した。
- [ ] AuditLogが安全。
- [ ] OWASP/STRIDE観点を確認した。
