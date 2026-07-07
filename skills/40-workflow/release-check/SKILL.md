---
name: release-check
description: リリース確認Skill。CI、DORA、security gate、staging/production smoke、runbook、release note、残リスクを確認するときに使う。
---

# Release Check

## Purpose

リリース前に品質、運用、セキュリティ、ドキュメントのゲートを確認する。

## When to use

- release判断前。
- staging/production smoke前後。
- 運用runbookを更新するとき。

## Inputs

- PR/commit。
- CI結果。
- smoke runbook。
- release checklist。
- 残リスク。

## Process

1. required CIを確認する。
2. security、auth、secret、AuditLogを確認する。
3. staging/production smoke証跡を確認する。
4. rollback、monitoring、backup、workerを確認する。
5. release noteと既知リスクをまとめる。
6. release reviewを `docs/review/` に保存する。

## Output

- release判定。
- smoke証跡。
- release note。
- 残リスク。

## Constraints

- live CIやsmokeなしで完了扱いしない。
- 重大なsecurity blockerをリスク受容なしに進めない。
- 本番secretを記録しない。

## Checklist

- [ ] CIが成功。
- [ ] smoke証跡がある。
- [ ] rollback方針がある。
- [ ] 監視とworkerを確認した。
- [ ] release reviewがある。
